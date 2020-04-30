import Foundation
import Combine

final class Floodgate<State, Event, S: Subscriber>: FeedbackEventConsumer<Event>, Subscription where S.Input == State, S.Failure == Never {
    struct QueueState {
        var events: [(Event, Token)] = []
        var isOuterLifetimeEnded = false
        var hasEvents: Bool {
            events.isEmpty == false && isOuterLifetimeEnded == false
        }
    }

    let stateDidChange = PassthroughSubject<(State, Event?), Never>()

    private let reducerLock = NSLock()
    private var state: State
    private var hasStarted = false
    private var cancelable: Cancellable?

    private let queue = Atomic(QueueState())
    private let reducer: Reducer<State, Event>
    private let feedbacks: [Feedback<State, Event>]
    private let sink: S

    init(
        state: State,
        feedbacks: [Feedback<State, Event>],
        sink: S,
        reducer: Reducer<State, Event>
    ) {
        self.state = state
        self.feedbacks = feedbacks
        self.sink = sink
        self.reducer = reducer
    }

    func bootstrap() {
        reducerLock.lock()
        defer { reducerLock.unlock() }

        guard !hasStarted else { return }
        hasStarted = true
        self.cancelable = feedbacks.map { $0.events(stateDidChange.eraseToAnyPublisher(), self) }
        _ = self.sink.receive(state)
        stateDidChange.send((state, nil))
        drainEvents()
    }

    func request(_ demand: Subscribers.Demand) {}

    func cancel() {
        stateDidChange.send(completion: .finished)
        cancelable?.cancel()
        queue.modify {
            $0.isOuterLifetimeEnded = true
        }
    }

    override func process(_ event: Event, for token: Token) {
        enqueue(event, for: token)

        if reducerLock.try() {
            repeat {
                drainEvents()
                reducerLock.unlock()
            } while queue.withValue({ $0.hasEvents }) && reducerLock.try()
            // ^^^
            // Restart the event draining after we unlock the reducer lock, iff:
            //
            // 1. the queue still has unprocessed events; and
            // 2. no concurrent actor has taken the reducer lock, which implies no event draining would be started
            //    unless we take active action.
            //
            // This eliminates a race condition in the following sequence of operations:
            //
            // |              Thread A              |              Thread B              |
            // |------------------------------------|------------------------------------|
            // |     concurrent dequeue: no item    |                                    |
            // |                                    |         concurrent enqueue         |
            // |                                    |         trylock lock: BUSY         |
            // |            unlock lock             |                                    |
            // |                                    |                                    |
            // |             <<<  The enqueued event is left unprocessed. >>>            |
            //
            // The trylock-unlock duo has a synchronize-with relationship, which ensures that Thread A must see any
            // concurrent enqueue that *happens before* the trylock.
        }
    }

    override func dequeueAllEvents(for token: Token) {
        queue.modify { $0.events.removeAll(where: { _, t in t == token }) }
    }

    private func enqueue(_ event: Event, for token: Token) {
        queue.modify { state -> QueueState in
            state.events.append((event, token))
            return state
        }
    }

    private func dequeue() -> Event? {
        queue.modify {
            guard !$0.isOuterLifetimeEnded, !$0.events.isEmpty else {
                return nil
            }
            return $0.events.removeFirst().0
        }
    }

    private func drainEvents() {
        // Drain any recursively produced events.
        while let next = dequeue() {
            consume(next)
        }
    }

    private func consume(_ event: Event) {
        reducer(&state, event)
        _ = sink.receive(state)
        stateDidChange.send((state, event))
    }
}

extension Publisher where Failure == Never {
    public func enqueue(to consumer: FeedbackEventConsumer<Output>) -> Publishers.Enqueue<Self> {
        return Publishers.Enqueue(upstream: self, consumer: consumer)
    }
}

extension Publishers {
    public struct Enqueue<Upstream: Publisher>: Publisher where Upstream.Failure == Never {
        public typealias Output = Never
        public typealias Failure = Never
        private let upstream: Upstream
        private let consumer: FeedbackEventConsumer<Upstream.Output>

        init(upstream: Upstream, consumer: FeedbackEventConsumer<Upstream.Output>) {
            self.upstream = upstream
            self.consumer = consumer
        }

        public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
            let token = Token()
            self.upstream.handleEvents(
                receiveOutput: { (value) in
                    self.consumer.process(value, for: token)
                },
                receiveCancel: {
                    self.consumer.dequeueAllEvents(for: token)
                }
            )
            .flatMap { _ -> Empty<Never, Never> in
                return Empty()
            }
            .receive(subscriber: subscriber)
        }
    }
}


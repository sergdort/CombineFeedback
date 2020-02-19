import Foundation
import Combine

final class Floodgate<State, Event>: FeedbackEventConsumer<Event>, Subscription {
    struct QueueState {
        var events: [(Event, Token)] = []
        var isOuterLifetimeEnded = false
    }

    let stateDidChange = PassthroughSubject<State, Never>()

    private let reducerLock = NSLock()
    private var state: State
    private var hasStarted = false

    private let queue = Atomic(QueueState())
    private let reducer: Reducer<State, Event>

    init(state: State, reducer: @escaping Reducer<State, Event>) {
        self.state = state
        self.reducer = reducer
    }

    func bootstrap() {
        reducerLock.lock()
        defer { reducerLock.unlock() }

        guard !hasStarted else { return }
        hasStarted = true

        stateDidChange.send(state)
        drainEvents()
    }

    func request(_ demand: Subscribers.Demand) {}

    func cancel() {
        queue.modify {
            $0.isOuterLifetimeEnded = true
        }
    }

    override func process(_ event: Event, for token: Token) {
        if reducerLock.try() {
            // Fast path: No running effect.
            defer { reducerLock.unlock() }

            consume(event)
            drainEvents()
        } else {
            // Slow path: Enqueue the event for the running effect to drain it on behalf of us.
            enqueue(event, for: token)
        }
    }

    override func unqueueAllEvents(for token: Token) {
        queue.modify { $0.events.removeAll(where: { _, t in t == token }) }
    }

    func withValue<Result>(_ action: (State, Bool) -> Result) -> Result {
        reducerLock.perform { action(state, hasStarted) }
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
        stateDidChange.send(state)
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
                    self.consumer.unqueueAllEvents(for: token)
                }
            )
            .flatMap { (outuput) -> Empty<Never, Never> in
                return Empty()
            }
            .receive(subscriber: subscriber)
        }
    }
}


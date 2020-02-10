import Combine

public struct Feedback<State, Event> {
    let events: (_ state: AnyPublisher<State, Never>, _ output: FeedbackEventConsumer<Event>) -> Cancellable

    internal init(events: @escaping (_ state: AnyPublisher<State, Never>, _ output: FeedbackEventConsumer<Event>) -> Cancellable) {
        self.events = events
    }

    /// Creates a custom Feedback, with the complete liberty of defining the data flow.
    ///
    /// - important: While you may respond to state changes in whatever ways you prefer, you **must** enqueue produced
    ///              events using the `SignalProducer.enqueue(to:)` operator to the `FeedbackEventConsumer` provided
    ///              to you. Otherwise, the feedback loop will not be able to pick up and process your events.
    ///
    /// - parameters:
    ///   - setup: The setup closure to construct a data flow producing events in respond to changes from `state`,
    ///             and having them consumed by `output` using the `SignalProducer.enqueue(to:)` operator.
    public static func custom(
        _ setup: @escaping (
            _ state: AnyPublisher<State, Never>,
            _ output: FeedbackEventConsumer<Event>
        ) -> Cancellable
    ) -> Feedback<State, Event> {
        return Feedback(events: setup)
    }

    /// Creates a Feedback which re-evaluates the given effect every time the
    /// `Signal` derived from the latest state yields a new value.
    ///
    /// If the previous effect is still alive when a new one is about to start,
    /// the previous one would automatically be cancelled.
    ///
    /// - parameters:
    ///   - transform: The transform which derives a `Signal` of values from the
    ///                latest state.
    ///   - effects: The side effect accepting transformed values produced by
    ///              `transform` and yielding events that eventually affect
    ///              the state.
    public init<U, Effect: Publisher>(
        compacting transform: @escaping (AnyPublisher<State, Never>) -> AnyPublisher<U, Never>,
        effects: @escaping (U) -> Effect
    ) where Effect.Output == Event, Effect.Failure == Never {
        self.events = { state, output in
            // NOTE: `observe(on:)` should be applied on the inner producers, so
            //       that cancellation due to state changes would be able to
            //       cancel outstanding events that have already been scheduled.
            transform(state)
                .flatMapLatest { effects($0).enqueue(to: output) }
                .sink { _ in }
        }
    }

    /// Creates a Feedback which re-evaluates the given effect every time the
    /// state changes, and the transform consequentially yields a new value
    /// distinct from the last yielded value.
    ///
    /// If the previous effect is still alive when a new one is about to start,
    /// the previous one would automatically be cancelled.
    ///
    /// - parameters:
    ///   - transform: The transform to apply on the state.
    ///   - effects: The side effect accepting transformed values produced by
    ///              `transform` and yielding events that eventually affect
    ///              the state.
    public init<Control: Equatable, Effect: Publisher>(
        skippingRepeated transform: @escaping (State) -> Control?,
        effects: @escaping (Control) -> Effect
    ) where Effect.Output == Event, Effect.Failure == Never {
        self.init(
            compacting: {
                $0.map(transform)
                    .removeDuplicates()
                    .eraseToAnyPublisher()
            },
            effects: {
                $0.map(effects)?
                    .eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()
            }
        )
    }

    /// Creates a Feedback which re-evaluates the given effect every time the
    /// state changes.
    ///
    /// If the previous effect is still alive when a new one is about to start,
    /// the previous one would automatically be cancelled.
    ///
    /// - parameters:
    ///   - transform: The transform to apply on the state.
    ///   - effects: The side effect accepting transformed values produced by
    ///              `transform` and yielding events that eventually affect
    ///              the state.
    public init<Control, Effect: Publisher>(
        lensing transform: @escaping (State) -> Control?,
        effects: @escaping (Control) -> Effect
    ) where Effect.Output == Event, Effect.Failure == Never {
        self.init(
            compacting: {
                $0.map(transform).eraseToAnyPublisher()
            },
            effects: {
                $0.map(effects)?.eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()
            }
        )
    }

    /// Creates a Feedback which re-evaluates the given effect every time the
    /// given predicate passes.
    ///
    /// If the previous effect is still alive when a new one is about to start,
    /// the previous one would automatically be cancelled.
    ///
    /// - parameters:
    ///   - predicate: The predicate to apply on the state.
    ///   - effects: The side effect accepting the state and yielding events
    ///              that eventually affect the state.
    public init<Effect: Publisher>(
        predicate: @escaping (State) -> Bool,
        effects: @escaping (State) -> Effect
    ) where Effect.Output == Event, Effect.Failure == Never {
        self.init(
            compacting: { $0 },
            effects: { state in
                predicate(state) ? effects(state).eraseToAnyPublisher() : Empty().eraseToAnyPublisher()
            }
        )
    }

    /// Creates a Feedback which re-evaluates the given effect every time the
    /// state changes.
    ///
    /// If the previous effect is still alive when a new one is about to start,
    /// the previous one would automatically be cancelled.
    ///
    /// - parameters:
    ///   - effects: The side effect accepting the state and yielding events
    ///              that eventually affect the state.
    public init<Effect: Publisher>(
        effects: @escaping (State) -> Effect
    ) where Effect.Output == Event, Effect.Failure == Never {
        self.init(compacting: { $0 }, effects: effects)
    }
}

extension Feedback {
    public static func pullback<LocalState, LocalEvent>(
        feedback: Feedback<LocalState, LocalEvent>,
        value: KeyPath<State, LocalState>,
        event: @escaping (LocalEvent) -> Event
    ) -> Feedback<State, Event> {
        return Feedback.custom { (state, consumer) -> Cancellable in
            return feedback.events(
                state.map(value).eraseToAnyPublisher(),
                consumer.pullback(event)
            )
        }
    }

    public static func combine(_ feedbacks: Feedback<State, Event>...) -> Feedback<State, Event> {
        return Feedback.custom { (state, consumer) -> Cancellable in
            return feedbacks.map { (feedback) -> Cancellable in
                return feedback.events(state, consumer)
            }
        }
    }

    public func mapEvent<U>(_ f: @escaping (Event) -> U) -> Feedback<State, U> {
        return Feedback<State, U>.custom { (state, consumer) -> Cancellable in
            self.events(state, consumer.pullback(f))
        }
    }

    public static var input: (feedback: Feedback, observer: (Event) -> Void) {
        let subject = PassthroughSubject<Event, Never>()
        let feedback = Feedback.custom { (state, consumer) -> Cancellable in
            subject.enqueue(to: consumer).sink(receiveValue: { _ in })
        }
        return (feedback, subject.send)
    }
}

extension Array: Cancellable where Element == Cancellable {
    public func cancel() {
        for element in self {
            element.cancel()
        }
    }
}

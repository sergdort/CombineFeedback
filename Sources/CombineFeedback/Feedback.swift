import Combine

public struct Feedback<State, Event> {
    public let events: (AnyPublisher<State, Never>) -> AnyPublisher<Event, Never>

    /// Creates an arbitrary Feedback, which evaluates side effects reactively
    /// to the latest state, and eventually produces events that affect the
    /// state.
    ///
    /// - parameters:
    ///   - events: The transform which derives a `Publisher` of events from the
    ///             latest state.
    public init<E: Publisher>(
        events: @escaping (AnyPublisher<State, Never>) -> E
    ) where E.Output == Event, E.Failure == Never {
        self.events = { (state) -> AnyPublisher<Event, Never> in
            events(state)
                .eraseToAnyPublisher()
        }
    }

    /// Creates a Feedback which re-evaluates the given effect every time the
    /// `Publisher` derived from the latest state yields a new value.
    ///
    /// If the previous effect is still alive when a new one is about to start,
    /// the previous one would automatically be cancelled.
    ///
    /// - parameters:
    ///   - transform: The transform which derives a `Publisher` of values from the
    ///                latest state.
    ///   - effects: The side effect accepting transformed values produced by
    ///              `transform` and yielding events that eventually affect
    ///              the state.
    public init<U, Effect: Publisher>(
        deriving transform: @escaping (AnyPublisher<State, Never>) -> AnyPublisher<U, Never>,
        effects: @escaping (U) -> Effect
    ) where Effect.Output == Event, Effect.Failure == Never {
        self.events = { (state) -> AnyPublisher<Event, Never> in
            transform(state)
                .flatMapLatest(effects)
                .eraseToAnyPublisher()
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
            deriving: {
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
            deriving: {
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
            deriving: { $0 },
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
        self.init(deriving: { $0 }, effects: effects)
    }
}

extension Feedback {
    public static func pullback<LocalState, LocalEvent>(
        feedback: Feedback<LocalState, LocalEvent>,
        value: KeyPath<State, LocalState>,
        event: @escaping (LocalEvent) -> Event
    ) -> Feedback<State, Event> {
        Feedback<State, Event> { (state: AnyPublisher<State, Never>) -> AnyPublisher<Event, Never> in
            feedback.events(
                state.map(value).eraseToAnyPublisher()
            )
            .map(event).eraseToAnyPublisher()
        }
    }

    public static func combine(_ feedbacks: Feedback<State, Event>...) -> Feedback<State, Event> {
        return Feedback(events: { state -> Publishers.MergeMany<AnyPublisher<Event, Never>> in
            let events = feedbacks
                .map { feedbacks in
                    return feedbacks.events(state)
            }
            return Publishers.MergeMany(events)
        })
    }
}


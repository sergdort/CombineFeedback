import CasePaths
import Combine

public struct Feedback<State, Event> {
    let events: (_ state: AnyPublisher<(State, Event?), Never>, _ output: FeedbackEventConsumer<Event>) -> Cancellable

    internal init(events: @escaping (_ state: AnyPublisher<(State, Event?), Never>, _ output: FeedbackEventConsumer<Event>) -> Cancellable) {
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
            _ state: AnyPublisher<(State, Event?), Never>,
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
    public static func compacting<U, Effect: Publisher>(
        state transform: @escaping (AnyPublisher<State, Never>) -> AnyPublisher<U, Never>,
        effects: @escaping (U) -> Effect
    ) -> Feedback where Effect.Output == Event, Effect.Failure == Never {
        custom { (state, output) -> Cancellable in
            // NOTE: `observe(on:)` should be applied on the inner producers, so
            //       that cancellation due to state changes would be able to
            //       cancel outstanding events that have already been scheduled.
            transform(state.map(\.0).eraseToAnyPublisher())
                .flatMapLatest { effects($0).enqueue(to: output) }
                .start()
        }
    }

    public static func compacting<U, Effect: Publisher>(
        events transform: @escaping (AnyPublisher<Event, Never>) -> AnyPublisher<U, Never>,
        effects: @escaping (U) -> Effect
    ) -> Feedback where Effect.Output == Event, Effect.Failure == Never {
        custom { (state, output) -> Cancellable in
            // NOTE: `observe(on:)` should be applied on the inner producers, so
            //       that cancellation due to state changes would be able to
            //       cancel outstanding events that have already been scheduled.
            transform(state.map(\.1).compactMap { $0 }.eraseToAnyPublisher())
                .flatMapLatest { effects($0).enqueue(to: output) }
                .start()
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
    public static func skippingRepeated<Control: Equatable, Effect: Publisher>(
        state transform: @escaping (State) -> Control?,
        effects: @escaping (Control) -> Effect
    ) -> Feedback where Effect.Output == Event, Effect.Failure == Never {
        compacting(state: {
            $0.map(transform)
                .removeDuplicates()
                .eraseToAnyPublisher()
        }, effects: {
            $0.map(effects)?
                .eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()
        })
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
    public static func lensing<Control, Effect: Publisher>(
        state transform: @escaping (State) -> Control?,
        effects: @escaping (Control) -> Effect
    ) -> Feedback where Effect.Output == Event, Effect.Failure == Never {
        compacting(state: {
            $0.map(transform).eraseToAnyPublisher()
        }, effects: {
            $0.map(effects)?.eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()
        })
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
    public static func predicate<Effect: Publisher>(
        predicate: @escaping (State) -> Bool,
        effects: @escaping (State) -> Effect
    ) -> Feedback where Effect.Output == Event, Effect.Failure == Never {
        compacting(state: { $0 }, effects: { state in
            predicate(state) ? effects(state).eraseToAnyPublisher() : Empty().eraseToAnyPublisher()
        })
    }

    public static func lensing<Payload, Effect: Publisher>(
        event transform: @escaping (Event) -> Payload?,
        effects: @escaping (Payload) -> Effect
    ) -> Feedback where Effect.Output == Event, Effect.Failure == Never {
        compacting(events: {
            $0.map(transform).eraseToAnyPublisher()
        }, effects: {
            $0.map(effects)?.eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()
        })
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
    public static func middleware<Effect: Publisher>(
        _ effects: @escaping (State) -> Effect
    ) -> Feedback where Effect.Output == Event, Effect.Failure == Never {
        compacting(state: { $0 }, effects: effects)
    }
    
    /// Creates a Feedback which re-evaluates the given effect every time the
    /// state changes.
    ///
    /// If the previous effect is still alive when a new one is about to start,
    /// the previous one would automatically be cancelled.
    ///
    /// Important: State value is coming after reducer with an Event that caused the mutation
    ///
    /// - parameters:
    ///   - effects: The side effect accepting the state and yielding events
    ///              that eventually affect the state.
    public static func middleware<Effect: Publisher>(
        _ effects: @escaping (State, Event) -> Effect
    ) -> Feedback where Effect.Output == Event, Effect.Failure == Never {
        custom { (state, output) -> Cancellable in
            state.compactMap { s, e -> (State, Event)? in
                guard let e = e else {
                    return nil
                }
                return (s, e)
            }
            .flatMapLatest {
                effects($0, $1).enqueue(to: output)
            }
            .start()
        }
    }
}

extension Feedback {
    public func pullback<GlobalState, GlobalEvent>(
        value: KeyPath<GlobalState, State>,
        event: CasePath<GlobalEvent, Event>
    ) -> Feedback<GlobalState, GlobalEvent> {
        return .custom { (state, consumer) -> Cancellable in
            let state = state.map {
                return ($0[keyPath: value], $1.flatMap(event.extract(from:)))
            }.eraseToAnyPublisher()
            return self.events(
                state,
                consumer.pullback(event.embed)
            )
        }
    }

    public static func combine(_ feedbacks: Feedback<State, Event>...) -> Feedback<State, Event> {
        return Feedback.custom { (state, consumer) -> Cancellable in
            feedbacks.map { (feedback) -> Cancellable in
                return feedback.events(state, consumer)
            }
        }
    }

    public static var input: (feedback: Feedback, observer: (Event) -> Void) {
        let subject = PassthroughSubject<Event, Never>()
        let feedback = Feedback.custom { (_, consumer) -> Cancellable in
            subject.enqueue(to: consumer).start()
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

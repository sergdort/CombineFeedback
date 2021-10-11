import CasePaths
import Combine

public struct Feedback<State, Event, Dependency> {
  public let events: (
    _ state: AnyPublisher<(State, Event?), Never>,
    _ output: FeedbackEventConsumer<Event>,
    _ dependency: Dependency
  ) -> Cancellable

  internal init(events: @escaping (
    _ state: AnyPublisher<(State, Event?), Never>,
    _ output: FeedbackEventConsumer<Event>,
    _ dependency: Dependency
  ) -> Cancellable) {
    self.events = events
  }

  /// Creates a custom Feedback, with the complete liberty of defining the data flow.
  ///
  /// - important: While you may respond to state changes in whatever ways you prefer, you **must** enqueue produced
  ///              events using the `Publisher.enqueue(to:)` operator to the `FeedbackEventConsumer` provided
  ///              to you. Otherwise, the feedback loop will not be able to pick up and process your events.
  ///
  /// - parameters:
  ///   - setup: The setup closure to construct a data flow producing events in respond to changes from `state`,
  ///             and having them consumed by `output` using the `SignalProducer.enqueue(to:)` operator.
  public static func custom<P: Publisher>(
    _ setup: @escaping (
      _ state: AnyPublisher<(State, Event?), Never>,
      _ output: FeedbackEventConsumer<Event>,
      _ dependency: Dependency
    ) -> P
  ) -> Feedback where P.Failure == Never, P.Output == Never {
    return Feedback { state, output, dependency -> Cancellable in
      setup(state, output, dependency).start()
    }
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
    effects: @escaping (U, Dependency) -> Effect
  ) -> Feedback where Effect.Output == Event, Effect.Failure == Never {
    custom { state, output, dependency in
      // NOTE: `observe(on:)` should be applied on the inner producers, so
      //       that cancellation due to state changes would be able to
      //       cancel outstanding events that have already been scheduled.
      transform(state.map(\.0).eraseToAnyPublisher())
        .flatMapLatest { effects($0, dependency).enqueue(to: output) }
    }
  }

  public static func compacting<U, Effect: Publisher>(
    events transform: @escaping (AnyPublisher<Event, Never>) -> AnyPublisher<U, Never>,
    effects: @escaping (U, Dependency) -> Effect
  ) -> Feedback where Effect.Output == Event, Effect.Failure == Never {
    custom { state, output, dependency in
      // NOTE: `observe(on:)` should be applied on the inner producers, so
      //       that cancellation due to state changes would be able to
      //       cancel outstanding events that have already been scheduled.
      transform(state.map(\.1).compactMap { $0 }.eraseToAnyPublisher())
        .flatMapLatest { effects($0, dependency).enqueue(to: output) }
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
    effects: @escaping (Control, Dependency) -> Effect
  ) -> Feedback where Effect.Output == Event, Effect.Failure == Never {
    compacting(state: {
      $0.map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }, effects: { control, dependency in
      control
        .map { effects($0, dependency) }?
        .eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()
    })
  }

  @available(iOS 15.0, *)
  public static func skippingRepeated<Control: Equatable>(
    state transform: @escaping (State) -> Control?,
    effect: @escaping (Control, Dependency) async -> Event
  ) -> Feedback {
    compacting(state: {
      $0.map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }, effects: { control, dependency -> AnyPublisher<Event, Never> in
      if let control = control {
        return TaskPublisher {
          await effect(control, dependency)
        }.eraseToAnyPublisher()
      } else {
        return Empty().eraseToAnyPublisher()
      }
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
    effects: @escaping (Control, Dependency) -> Effect
  ) -> Feedback where Effect.Output == Event, Effect.Failure == Never {
    compacting(state: {
      $0.map(transform).eraseToAnyPublisher()
    }, effects: { control, dependency in
      control.map { effects($0, dependency) }?
        .eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()
    })
  }

  @available(iOS 15.0, *)
  public static func lensing<Control>(
    state transform: @escaping (State) -> Control?,
    effects: @escaping (Control, Dependency) async -> Event
  ) -> Feedback {
    compacting(state: {
      $0.map(transform).eraseToAnyPublisher()
    }, effects: { control, dependency -> AnyPublisher<Event, Never> in
      if let control = control {
        return TaskPublisher {
          await effects(control, dependency)
        }
        .eraseToAnyPublisher()
      } else {
        return Empty().eraseToAnyPublisher()
      }
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
    effects: @escaping (State, Dependency) -> Effect
  ) -> Feedback where Effect.Output == Event, Effect.Failure == Never {
    return firstValueAfterNil({ state -> State? in
      predicate(state) ? state : nil
    }, effects: effects)
  }

  /// Creates a Feedback which re-evaluates the given effect every time the
  /// given predicate passes.
  ///
  /// If the previous effect is still alive when a new one is about to start,
  /// the previous one would automatically be cancelled.
  ///
  /// - Parameters:
  ///   - predicate: The predicate to apply on the state.
  ///   - effect: The side effect accepting the state and yielding events that eventually affect the state.
  @available(iOS 15.0, *)
  public static func predicate(
    predicate: @escaping (State) -> Bool,
    effect: @escaping (State, Dependency) async -> Event
  ) -> Feedback {
    return firstValueAfterNil { state -> State? in
      predicate(state) ? state : nil
    } effect: { state, dependency in
      await effect(state, dependency)
    }
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
  public static func lensing<Payload, Effect: Publisher>(
    event transform: @escaping (Event) -> Payload?,
    effects: @escaping (Payload, Dependency) -> Effect
  ) -> Feedback where Effect.Output == Event, Effect.Failure == Never {
    compacting(events: {
      $0.map(transform).eraseToAnyPublisher()
    }, effects: { payload, dependency in
      payload.map { effects($0, dependency) }?
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
  @available(iOS 15.0, *)
  public static func lensing<Payload>(
    event transform: @escaping (Event) -> Payload?,
    effect: @escaping (Payload, Dependency) async -> Event
  ) -> Feedback {
    compacting(events: {
      $0.map(transform).eraseToAnyPublisher()
    }, effects: { payload, dependency -> AnyPublisher<Event, Never> in
      if let payload = payload {
        return TaskPublisher {
          await effect(payload, dependency)
        }
        .eraseToAnyPublisher()
      } else {
        return Empty().eraseToAnyPublisher()
      }
    })
  }

  public static func firstValueAfterNil<Value, Effect: Publisher>(
    _ transform: @escaping (State) -> Value?,
    effects: @escaping (Value, Dependency) -> Effect
  ) -> Feedback where Effect.Output == Event, Effect.Failure == Never {
    return .compacting(
      state: { state -> AnyPublisher<NilEdgeTransition<Value>, Never> in
        state.scan((lastWasNil: true, output: NilEdgeTransition<Value>?.none)) { acum, state in
          var temp = acum
          let result = transform(state)
          temp.output = nil

          switch (temp.lastWasNil, result) {
          case (true, .none), (false, .some):
            return temp
          case let (true, .some(value)):
            temp.lastWasNil = false
            temp.output = .populated(value)
          case (false, .none):
            temp.lastWasNil = true
            temp.output = .cleared
          }
          return temp
        }
        .compactMap(\.output)
        .eraseToAnyPublisher()
      },
      effects: { transition, dependency -> AnyPublisher<Effect.Output, Effect.Failure> in
        switch transition {
        case let .populated(value):
          return effects(value, dependency).eraseToAnyPublisher()
        case .cleared:
          return Empty().eraseToAnyPublisher()
        }
      }
    )
  }

  @available(iOS 15.0, *)
  public static func firstValueAfterNil<Value>(
    _ transform: @escaping (State) -> Value?,
    effect: @escaping (Value, Dependency) async -> Event
  ) -> Feedback {
    .firstValueAfterNil(transform) { value, dependency in
      TaskPublisher {
        await effect(value, dependency)
      }
    }
  }

  /// Redux like Middleware signature Feedback factory method that lets you perform side effects when state changes
  ///
  /// If the previous effect is still alive when a new one is about to start,
  /// the previous one would automatically be cancelled.
  ///
  /// - parameters:
  ///   - effects: The side effect accepting the state and yielding events
  ///              that eventually affect the state.
  public static func middleware<Effect: Publisher>(
    _ effects: @escaping (State, Dependency) -> Effect
  ) -> Feedback where Effect.Output == Event, Effect.Failure == Never {
    compacting(state: { $0 }, effects: effects)
  }

  /// Redux like Middleware signature Feedback factory method that lets you perform side effects when state changes
  ///
  /// If the previous effect is still alive when a new one is about to start,
  /// the previous one would automatically be cancelled.
  ///
  /// - parameters:
  ///   - effects: The side effect accepting the state and yielding events
  ///              that eventually affect the state.
  @available(iOS 15.0, *)
  public static func middleware(
    _ effect: @escaping (State, Dependency) async -> Event
  ) -> Feedback {
    compacting(state: { $0 }, effects: { state, dependency in
      TaskPublisher {
        await effect(state, dependency)
      }
    })
  }

  /// Redux like Middleware signature Feedback factory method that lets you perform side effects when state changes, also knowing which event cased it
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
    _ effects: @escaping (State, Event, Dependency) -> Effect
  ) -> Feedback where Effect.Output == Event, Effect.Failure == Never {
    custom { state, output, dependency in
      state.compactMap { s, e -> (State, Event)? in
        guard let e = e else {
          return nil
        }
        return (s, e)
      }
      .flatMapLatest {
        effects($0, $1, dependency)
          .enqueue(to: output)
      }
    }
  }

  /// Redux like Middleware signature Feedback factory method that lets you perform side effects when state changes, also knowing which event cased it
  ///
  /// If the previous effect is still alive when a new one is about to start,
  /// the previous one would automatically be cancelled.
  ///
  /// Important: State value is coming after reducer with an Event that caused the mutation
  ///
  /// - parameters:
  ///   - effects: The side effect accepting the state and yielding events
  ///              that eventually affect the state.
  @available(iOS 15.0, *)
  public static func middleware(
    _ effects: @escaping (State, Event, Dependency) async -> Event
  ) -> Feedback {
    custom { state, output, dependency in
      state.compactMap { s, e -> (State, Event)? in
        guard let e = e else {
          return nil
        }
        return (s, e)
      }
      .flatMapLatest { state, event in
        TaskPublisher {
          await effects(state, event, dependency)
        }
        .enqueue(to: output)
      }
    }
  }

  /// Redux like Middleware signature Feedback factory method that lets you perform side effects when state changes, also knowing which event cased it
  ///
  /// If the previous effect is still alive when a new one is about to start,
  /// the previous one would automatically be cancelled.
  ///
  /// Important: State value is coming after reducer with an Event that caused the mutation
  ///
  /// - parameters:
  ///   - effects: The side effect accepting the state and yielding events
  ///              that eventually affect the state.
  @available(iOS 15.0, *)
  public static func middleware(
    _ effect: @escaping (Event, Dependency) async -> Event
  ) -> Feedback {
    custom { state, output, dependency in
      state.compactMap { _, e -> Event? in
        guard let e = e else {
          return nil
        }
        return e
      }
      .flatMapLatest { event in
        TaskPublisher {
          await effect(event, dependency)
        }
        .enqueue(to: output)
      }
    }
  }
}

public extension Feedback {
  /// Transforms a Feedback that works on local state, event, and dependency into one that works on
  /// global state, action and dependency. It accomplishes this by providing 3 transformations to
  /// the method:
  ///
  ///   * A key path that can get a piece of local state from the global state.
  ///   * A case path that can extract/embed a local event into a global event.
  ///   * A function that can transform the global dependency into a local dependency.
  func pullback<GlobalState, GlobalEvent, GlobalDependency>(
    value: KeyPath<GlobalState, State>,
    event: CasePath<GlobalEvent, Event>,
    dependency toLocal: @escaping (GlobalDependency) -> Dependency
  ) -> Feedback<GlobalState, GlobalEvent, GlobalDependency> {
    return Feedback<GlobalState, GlobalEvent, GlobalDependency>(events: { state, consumer, dependency in
      let state = state.map {
        ($0[keyPath: value], $1.flatMap(event.extract(from:)))
      }.eraseToAnyPublisher()
      return self.events(
        state,
        consumer.pullback(event.embed),
        toLocal(dependency)
      )
    })
  }

  /// Transforms a Feedback that works on local state, event, and dependency into one that works on
  /// global state, action and dependency. It accomplishes this by providing 3 transformations to
  /// the method:
  ///
  /// An application may model parts of its state with enums. For example, app state may differ if a
  /// user is logged-in or not:
  ///
  /// ```swift
  /// enum AppState {
  ///   case loggedIn(LoggedInState)
  ///   case loggedOut(LoggedOutState)
  /// }
  /// ```
  ///
  ///   * A case path that can extract/embed a local state into a global state.
  ///   * A case path that can extract/embed a local event into a global event.
  ///   * A function that can transform the global dependency into a local dependency.
  func pullback<GlobalState, GlobalEvent, GlobalDependency>(
    value: CasePath<GlobalState, State>,
    event: CasePath<GlobalEvent, Event>,
    dependency toLocal: @escaping (GlobalDependency) -> Dependency
  ) -> Feedback<GlobalState, GlobalEvent, GlobalDependency> {
    return Feedback<GlobalState, GlobalEvent, GlobalDependency>(events: { state, consumer, dependency in
      let state: AnyPublisher<(State, Event?), Never> = state.compactMap { (stateAndEvent: (GlobalState, GlobalEvent?)) -> (State, Event?)? in
        guard let localState = value.extract(from: stateAndEvent.0) else {
          return nil
        }
        return (localState, stateAndEvent.1.flatMap(event.extract(from:)))
      }.eraseToAnyPublisher()
      return self.events(
        state,
        consumer.pullback(event.embed),
        toLocal(dependency)
      )
    })
  }

  static func combine(
    _ feedbacks: Feedback...) -> Feedback
  {
    return Feedback { (state, consumer, dependency) -> Cancellable in
      feedbacks.map { (feedback) -> Cancellable in
        feedback.events(state, consumer, dependency)
      }
    }
  }

  static var input: (feedback: Feedback, observer: (Event) -> Void) {
    let subject = PassthroughSubject<Event, Never>()
    let feedback = Feedback.custom { _, consumer, _ in
      subject.enqueue(to: consumer)
    }
    return (feedback, subject.send)
  }
}

public extension Feedback {
  func optional() -> Feedback<State?, Event, Dependency> {
    return Feedback<State?, Event, Dependency> { state, output, dependency in
      self.events(
        state.filter { stateAndEvent -> Bool in
          stateAndEvent.0 != nil
        }
        .map { ($0!, $1) }
        .eraseToAnyPublisher(),
        output,
        dependency
      )
    }
  }
}

extension Array: Cancellable where Element == Cancellable {
  public func cancel() {
    for element in self {
      element.cancel()
    }
  }
}

@available(iOS 15.0, *)
struct TaskPublisher<Output>: Publisher {
  typealias Failure = Never

  let work: () async -> Output

  init(work: @escaping () async -> Output) {
    self.work = work
  }

  func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
    let subscription = TaskSubscription(work: work, subscriber: subscriber)
    subscriber.receive(subscription: subscription)
    subscription.start()
  }

  final class TaskSubscription<Output, Downstream: Subscriber>: Combine.Subscription where Downstream.Input == Output, Downstream.Failure == Never {
    private var handle: Task<Output, Never>?
    private let work: () async -> Output
    private let subscriber: Downstream

    init(work: @escaping () async -> Output, subscriber: Downstream) {
      self.work = work
      self.subscriber = subscriber
    }

    func start() {
      self.handle = Task.init { [subscriber, work] in
        let result = await work()
        _ = subscriber.receive(result)
        subscriber.receive(completion: .finished)
        return result
      }
    }

    func request(_ demand: Subscribers.Demand) {}

    func cancel() {
      handle?.cancel()
    }
  }
}

private enum NilEdgeTransition<Value> {
  case populated(Value)
  case cleared
}

import CasePaths
import Combine
import Foundation

public struct FeedbackInput<State, Event> {
  public struct Update {
    public let state: State
    public let event: Event?
  }

  public let updates: AnyPublisher<Update, Never>
  public let states: AnyPublisher<State, Never>
  public let events: AnyPublisher<Event, Never>

  init(updates: AnyPublisher<Update, Never>) {
    self.updates = updates
    self.states = updates.map(\.state).eraseToAnyPublisher()
    self.events = updates.compactMap(\.event).eraseToAnyPublisher()
  }

  init(updates: AnyPublisher<(State, Event?), Never>) {
    self.init(
      updates: updates
        .map { Update(state: $0.0, event: $0.1) }
        .eraseToAnyPublisher()
    )
  }

  public func changes<Value: Equatable>(of projection: @escaping (State) -> Value) -> AnyPublisher<Value, Never> {
    states
      .map(projection)
      .removeDuplicates()
      .eraseToAnyPublisher()
  }

  public func changes<Value: Equatable>(of projection: @escaping (State) -> Value?) -> AnyPublisher<Value?, Never> {
    states
      .map(projection)
      .removeDuplicates { lhs, rhs in lhs == rhs }
      .eraseToAnyPublisher()
  }
}

public struct FeedbackOutput<Event> {
  let consumer: FeedbackEventConsumer<Event>
}

public struct Feedback<State, Event>: StateMachine {
  public typealias Body = Never

  let run: (FeedbackInput<State, Event>, FeedbackOutput<Event>) -> Cancellable

  init(run: @escaping (FeedbackInput<State, Event>, FeedbackOutput<Event>) -> Cancellable) {
    self.run = run
  }

  public static func custom<P: Publisher>(
    _ setup: @escaping (FeedbackInput<State, Event>, FeedbackOutput<Event>) -> P
  ) -> Feedback where P.Output == Never, P.Failure == Never {
    Feedback { input, output in
      setup(input, output).start()
    }
  }

  public func _resolve() -> ResolvedMachine<State, Event> {
    ResolvedMachine(reducer: Reducer { _, _ in }, feedbacks: [self])
  }

  static func combine(_ feedbacks: Feedback...) -> Feedback {
    Feedback { input, output in
      feedbacks.map { $0.run(input, output) }
    }
  }

  static var input: (feedback: Feedback, observer: (Event) -> Void) {
    let subject = PassthroughSubject<Event, Never>()
    let feedback = Feedback.custom { _, output in
      subject.enqueue(to: output)
    }
    return (feedback, subject.send)
  }
}

func scopedFeedback<ParentState, ParentEvent, ChildState, ChildEvent>(
  _ feedback: Feedback<ChildState, ChildEvent>,
  state stateKeyPath: KeyPath<ParentState, ChildState>,
  event eventKeyPath: CaseKeyPath<ParentEvent, ChildEvent>
) -> Feedback<ParentState, ParentEvent> where ParentEvent: CasePathable {
  Feedback<ParentState, ParentEvent> { input, output in
    let childInput = FeedbackInput<ChildState, ChildEvent>(
      updates: input.updates
        .map { update in
          FeedbackInput<ChildState, ChildEvent>.Update(
            state: update.state[keyPath: stateKeyPath],
            event: update.event.flatMap { $0[case: eventKeyPath] }
          )
        }
        .eraseToAnyPublisher()
    )
    return feedback.run(childInput, FeedbackOutput<ChildEvent>(consumer: output.consumer.mapInput { eventKeyPath($0) }))
  }
}

func scopedFeedback<ParentState, ParentEvent, ChildState, ChildEvent>(
  _ feedback: Feedback<ChildState, ChildEvent>,
  state stateKeyPath: CaseKeyPath<ParentState, ChildState>,
  event eventKeyPath: CaseKeyPath<ParentEvent, ChildEvent>
) -> Feedback<ParentState, ParentEvent> where ParentState: CasePathable, ParentEvent: CasePathable {
  optionalScopedFeedback(
    feedback,
    state: { $0[case: stateKeyPath] },
    event: eventKeyPath
  )
}

func scopedFeedback<ParentState, ParentEvent, ChildState, ChildEvent>(
  _ feedback: Feedback<ChildState, ChildEvent>,
  state stateKeyPath: KeyPath<ParentState, ChildState?>,
  event eventKeyPath: CaseKeyPath<ParentEvent, ChildEvent>
) -> Feedback<ParentState, ParentEvent> where ParentEvent: CasePathable {
  optionalScopedFeedback(
    feedback,
    state: { $0[keyPath: stateKeyPath] },
    event: eventKeyPath
  )
}

private func optionalScopedFeedback<ParentState, ParentEvent, ChildState, ChildEvent>(
  _ feedback: Feedback<ChildState, ChildEvent>,
  state: @escaping (ParentState) -> ChildState?,
  event eventKeyPath: CaseKeyPath<ParentEvent, ChildEvent>
) -> Feedback<ParentState, ParentEvent> where ParentEvent: CasePathable {
  Feedback<ParentState, ParentEvent> { input, output in
    OptionalFeedbackSubscription(
      updates: input.updates,
      output: FeedbackOutput<ChildEvent>(consumer: output.consumer.mapInput { eventKeyPath($0) }),
      state: state,
      event: eventKeyPath,
      run: feedback.run
    )
  }
}

public struct OnChange<State, Event, Value>: StateMachine {
  public typealias Body = Never

  private let feedback: Feedback<State, Event>

  public init<Effect: Publisher>(
    of projection: @escaping (State) -> Value,
    _ effect: @escaping (Value) -> Effect
  ) where Value: Equatable, Effect.Output == Event, Effect.Failure == Never {
    self.feedback = Feedback.custom { input, output in
      input.changes(of: projection)
        .flatMapLatest { effect($0).enqueue(to: output) }
    }
  }

  public init<Effect: Publisher>(
    of projection: @escaping (State) -> Value?,
    _ effect: @escaping (Value) -> Effect
  ) where Value: Equatable, Effect.Output == Event, Effect.Failure == Never {
    self.feedback = Feedback.custom { input, output in
      input.changes(of: projection)
        .flatMapLatest { value -> AnyPublisher<Never, Never> in
          guard let value else { return Empty().eraseToAnyPublisher() }
          return effect(value).enqueue(to: output).eraseToAnyPublisher()
        }
    }
  }

  public init(
    of projection: @escaping (State) -> Value,
    _ effect: @escaping (Value) -> Event
  ) where Value: Equatable {
    self.init(of: projection) { value in
      Just(effect(value))
    }
  }

  public init(
    of projection: @escaping (State) -> Value?,
    _ effect: @escaping (Value) -> Event
  ) where Value: Equatable {
    self.init(of: projection) { value in
      Just(effect(value))
    }
  }

  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  public init(
    of projection: @escaping (State) -> Value,
    _ effect: @escaping (Value) async -> Event
  ) where Value: Equatable {
    self.init(of: projection) { value in
      TaskPublisher { await effect(value) }
    }
  }

  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  public init(
    of projection: @escaping (State) -> Value?,
    _ effect: @escaping (Value) async -> Event
  ) where Value: Equatable {
    self.init(of: projection) { value in
      TaskPublisher { await effect(value) }
    }
  }

  @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
  public init<S: AsyncSequence & Sendable>(
    of projection: @escaping (State) -> Value,
    _ effect: @escaping (Value) -> S
  ) where Value: Equatable, S.Element == Event, S.Failure == Never, S.AsyncIterator: Sendable {
    self.init(of: projection) { value in
      AsyncSequencePublisher(effect(value))
    }
  }

  @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
  public init<S: AsyncSequence & Sendable>(
    of projection: @escaping (State) -> Value?,
    _ effect: @escaping (Value) -> S
  ) where Value: Equatable, S.Element == Event, S.Failure == Never, S.AsyncIterator: Sendable {
    self.init(of: projection) { value in
      AsyncSequencePublisher(effect(value))
    }
  }

  public func _resolve() -> ResolvedMachine<State, Event> {
    feedback._resolve()
  }
}

public struct OnEvent<State, Event, Payload>: StateMachine {
  public typealias Body = Never

  private let feedback: Feedback<State, Event>

  public init<Effect: Publisher>(
    _ eventCasePath: CaseKeyPath<Event, Payload>,
    _ effect: @escaping (Payload) -> Effect
  ) where Event: CasePathable, Effect.Output == Event, Effect.Failure == Never {
    self.feedback = Feedback.custom { input, output in
      input.events
        .compactMap { $0[case: eventCasePath] }
        .flatMapLatest { effect($0).enqueue(to: output) }
    }
  }

  public init<Effect: Publisher>(
    _ eventCasePath: CaseKeyPath<Event, Void>,
    _ effect: @escaping () -> Effect
  ) where Event: CasePathable, Payload == Void, Effect.Output == Event, Effect.Failure == Never {
    self.init(eventCasePath) { _ in effect() }
  }

  public init(
    _ eventCasePath: CaseKeyPath<Event, Payload>,
    _ effect: @escaping (Payload) -> Event
  ) where Event: CasePathable {
    self.init(eventCasePath) { payload in
      Just(effect(payload))
    }
  }

  public init(
    _ eventCasePath: CaseKeyPath<Event, Void>,
    _ effect: @escaping () -> Event
  ) where Event: CasePathable, Payload == Void {
    self.init(eventCasePath) { _ in effect() }
  }

  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  public init(
    _ eventCasePath: CaseKeyPath<Event, Payload>,
    _ effect: @escaping (Payload) async -> Event
  ) where Event: CasePathable {
    self.init(eventCasePath) { payload in
      TaskPublisher { await effect(payload) }
    }
  }

  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  public init(
    _ eventCasePath: CaseKeyPath<Event, Void>,
    _ effect: @escaping () async -> Event
  ) where Event: CasePathable, Payload == Void {
    self.init(eventCasePath) { _ in
      TaskPublisher { await effect() }
    }
  }

  @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
  public init<S: AsyncSequence & Sendable>(
    _ eventCasePath: CaseKeyPath<Event, Payload>,
    _ effect: @escaping (Payload) -> S
  ) where Event: CasePathable, S.Element == Event, S.Failure == Never, S.AsyncIterator: Sendable {
    self.init(eventCasePath) { payload in
      AsyncSequencePublisher(effect(payload))
    }
  }

  public func _resolve() -> ResolvedMachine<State, Event> {
    feedback._resolve()
  }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct SideEffect<State, Event>: StateMachine {
  public typealias Body = Never

  private let feedback: Feedback<State, Event>

  public init(
    _ effect: @escaping (State, Event) async -> Void
  ) {
    self.feedback = Feedback.custom { input, _ in
      input.updates
        .compactMap { update -> (State, Event)? in
          update.event.map { (update.state, $0) }
        }
        .flatMap { state, event in
          VoidTaskPublisher { await effect(state, event) }
        }
    }
  }

  public func _resolve() -> ResolvedMachine<State, Event> {
    feedback._resolve()
  }
}

extension Array: @retroactive Cancellable where Element == Cancellable {
  public func cancel() {
    for element in self {
      element.cancel()
    }
  }
}

private final class OptionalFeedbackSubscription<ParentState, ParentEvent, State, Event>: Cancellable
where ParentEvent: CasePathable {
  private let lock = NSRecursiveLock()
  private let output: FeedbackOutput<Event>
  private let state: (ParentState) -> State?
  private let eventKeyPath: CaseKeyPath<ParentEvent, Event>
  private let run: (FeedbackInput<State, Event>, FeedbackOutput<Event>) -> Cancellable
  private var upstream: Cancellable?
  private var childInput: PassthroughSubject<FeedbackInput<State, Event>.Update, Never>?
  private var childCancellable: Cancellable?
  private var isCancelled = false

  init(
    updates: AnyPublisher<FeedbackInput<ParentState, ParentEvent>.Update, Never>,
    output: FeedbackOutput<Event>,
    state: @escaping (ParentState) -> State?,
    event eventKeyPath: CaseKeyPath<ParentEvent, Event>,
    run: @escaping (FeedbackInput<State, Event>, FeedbackOutput<Event>) -> Cancellable
  ) {
    self.output = output
    self.state = state
    self.eventKeyPath = eventKeyPath
    self.run = run
    self.upstream = updates.sink { [weak self] update in
      self?.receive(update)
    }
  }

  func cancel() {
    lock.lock()
    defer { lock.unlock() }

    guard !isCancelled else { return }
    isCancelled = true
    upstream?.cancel()
    upstream = nil
    cancelChild()
  }

  private func receive(_ update: FeedbackInput<ParentState, ParentEvent>.Update) {
    lock.lock()
    defer { lock.unlock() }

    guard !isCancelled else { return }

    guard let localState = state(update.state) else {
      cancelChild()
      return
    }

    let localUpdate = FeedbackInput<State, Event>.Update(
      state: localState,
      event: update.event.flatMap { $0[case: eventKeyPath] }
    )

    if let childInput {
      childInput.send(localUpdate)
    } else {
      let childInput = PassthroughSubject<FeedbackInput<State, Event>.Update, Never>()
      self.childInput = childInput
      childCancellable = run(
        FeedbackInput<State, Event>(updates: childInput.eraseToAnyPublisher()),
        output
      )
      childInput.send(localUpdate)
    }
  }

  private func cancelChild() {
    childCancellable?.cancel()
    childCancellable = nil
    childInput = nil
  }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
struct TaskPublisher<Output>: Publisher {
  typealias Failure = Never

  let work: () async -> Output

  init(work: @escaping () async -> Output) {
    self.work = work
  }

  func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
    let subscription = TaskSubscription(work: work, subscriber: AnySubscriber(subscriber))
    subscriber.receive(subscription: subscription)
    subscription.start()
  }

  final class TaskSubscription: Combine.Subscription, @unchecked Sendable {
    private let lock = NSLock()
    private var isCancelled = false
    private var handle: Task<Void, Never>?
    private let work: () async -> Output
    private let subscriber: AnySubscriber<Output, Never>

    init(work: @escaping () async -> Output, subscriber: AnySubscriber<Output, Never>) {
      self.work = work
      self.subscriber = subscriber
    }

    func start() {
      lock.lock()
      // `start()` runs after `receive(subscription:)`, so a synchronous cancel
      // from the subscriber (or a concurrent cancel from a re-subscribing
      // operator) can land first. Without this guard the task would launch and
      // deliver to an already-cancelled subscriber, re-entering the loop as a
      // stale, already-flushed effect output.
      guard !isCancelled else {
        lock.unlock()
        return
      }
      self.handle = Task { [self] in
        let result = await work()
        // `cancel()` cancels this task, so `Task.isCancelled` covers a cancel
        // that arrives while `work()` is suspended. The lock above only closes
        // the cancel-before-`start()` window, which is not reachable here.
        guard !Task.isCancelled else {
          subscriber.receive(completion: .finished)
          return
        }
        _ = subscriber.receive(result)
        subscriber.receive(completion: .finished)
      }
      lock.unlock()
    }

    func request(_ demand: Subscribers.Demand) {}

    func cancel() {
      lock.lock()
      isCancelled = true
      let handle = self.handle
      self.handle = nil
      lock.unlock()
      handle?.cancel()
    }
  }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
private struct VoidTaskPublisher: Publisher {
  typealias Output = Never
  typealias Failure = Never

  let work: () async -> Void

  func receive<S>(subscriber: S) where S: Subscriber, Never == S.Input, Never == S.Failure {
    TaskPublisher(work: work)
      .flatMap { _ in Empty<Never, Never>() }
      .receive(subscriber: subscriber)
  }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
private struct AsyncSequencePublisher<Sequence: AsyncSequence & Sendable>: Publisher
where Sequence.Failure == Never, Sequence.AsyncIterator: Sendable {
  typealias Output = Sequence.Element
  typealias Failure = Never

  let sequence: Sequence

  init(_ sequence: Sequence) {
    self.sequence = sequence
  }

  func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Sequence.Element == S.Input {
    let subscription = Subscription(sequence: sequence, subscriber: AnySubscriber(subscriber))
    subscriber.receive(subscription: subscription)
    subscription.start()
  }

  final class Subscription: Combine.Subscription, @unchecked Sendable {
    private let lock = NSLock()
    private var isCancelled = false
    private var handle: Task<Void, Never>?
    private let sequence: Sequence
    private let subscriber: AnySubscriber<Sequence.Element, Never>

    init(sequence: Sequence, subscriber: AnySubscriber<Sequence.Element, Never>) {
      self.sequence = sequence
      self.subscriber = subscriber
    }

    func start() {
      lock.lock()
      // A cancel arriving between `receive(subscription:)` and `start()` must
      // stop the iteration from ever launching. See `TaskPublisher` for the
      // detailed rationale.
      guard !isCancelled else {
        lock.unlock()
        return
      }
      self.handle = Task { [self] in
        for await value in sequence {
          guard !Task.isCancelled else {
            subscriber.receive(completion: .finished)
            return
          }
          _ = subscriber.receive(value)
        }
        subscriber.receive(completion: .finished)
      }
      lock.unlock()
    }

    func request(_ demand: Subscribers.Demand) {}

    func cancel() {
      lock.lock()
      isCancelled = true
      let handle = self.handle
      self.handle = nil
      lock.unlock()
      handle?.cancel()
    }
  }
}

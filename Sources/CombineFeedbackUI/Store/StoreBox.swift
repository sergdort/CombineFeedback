import Combine
import CombineFeedback
import CasePaths

internal class RootStoreBox<State, Event>: StoreBoxBase<State, Event> {
  private let subject: CurrentValueSubject<State, Never>

  private let input = Feedback<State, Update>.input
  private var bag = Set<AnyCancellable>()

  override var _current: State {
    subject.value
  }

  override var publisher: AnyPublisher<State, Never> {
    subject.eraseToAnyPublisher()
  }

  public init(
    initial: State,
    feedbacks: [Feedback<State, Event>],
    reducer: Reducer<State, Event>
  ) {
    self.subject = CurrentValueSubject(initial)
    Publishers.FeedbackLoop(
      initial: initial,
      reduce: .init { state, update in
        switch update {
        case .event(let event):
          reducer(&state, event)
        case .mutation(let mutation):
          mutation.mutate(&state)
        }
      },
      feedbacks: feedbacks.map {
        $0.pullback(value: \.self, event: /Update.event)
      }
      .appending(self.input.feedback)
    )
    .sink(receiveValue: { [subject] state in
      subject.send(state)
    })
    .store(in: &bag)
  }

  override func send(event: Event) {
    self.input.observer(.event(event))
  }

  override func mutate<V>(keyPath: WritableKeyPath<State, V>, value: V) {
    self.input.observer(.mutation(Mutation(keyPath: keyPath, value: value)))
  }

  override func mutate(with mutation: Mutation<State>) {
    self.input.observer(.mutation(mutation))
  }

  override func scoped<S, E>(to scope: WritableKeyPath<State, S>, event: @escaping (E) -> Event) -> StoreBoxBase<S, E> {
    ScopedStoreBox(parent: self, value: scope, event: event)
  }

  private enum Update {
    case event(Event)
    case mutation(Mutation<State>)
  }
}

internal class ScopedStoreBox<RootState, RootEvent, ScopedState, ScopedEvent>: StoreBoxBase<ScopedState, ScopedEvent> {
  private let parent: StoreBoxBase<RootState, RootEvent>
  private let value: WritableKeyPath<RootState, ScopedState>
  private let eventTransform: (ScopedEvent) -> RootEvent

  override var _current: ScopedState {
    parent._current[keyPath: value]
  }

  override var publisher: AnyPublisher<ScopedState, Never> {
    parent.publisher.map(value).eraseToAnyPublisher()
  }

  init(
    parent: StoreBoxBase<RootState, RootEvent>,
    value: WritableKeyPath<RootState, ScopedState>,
    event: @escaping (ScopedEvent) -> RootEvent
  ) {
    self.parent = parent
    self.value = value
    self.eventTransform = event
  }

  override func send(event: ScopedEvent) {
    parent.send(event: eventTransform(event))
  }

  override func mutate(with mutation: Mutation<ScopedState>) {
    parent.mutate(with: Mutation<RootState>(mutate: { [value] rootState in
      var scopedState = rootState[keyPath: value]
      mutation.mutate(&scopedState)
      rootState[keyPath: value] = scopedState
    }))
  }

  override func mutate<V>(keyPath: WritableKeyPath<ScopedState, V>, value: V) {
    mutate(with: Mutation(keyPath: keyPath, value: value))
  }

  override func scoped<S, E>(to scope: WritableKeyPath<ScopedState, S>, event: @escaping (E) -> ScopedEvent) -> StoreBoxBase<S, E> {
    ScopedStoreBox<RootState, RootEvent, S, E>(
      parent: self.parent,
      value: value.appending(path: scope),
      event: { [eventTransform] in eventTransform(event($0)) }
    )
  }
}

internal class StoreBoxBase<State, Event> {
  /// Loop Internal SPI
  var _current: State { subclassMustImplement() }

  var publisher: AnyPublisher<State, Never> { subclassMustImplement() }

  func send(event: Event) {
    subclassMustImplement()
  }

  func mutate<V>(keyPath: WritableKeyPath<State, V>, value: V) {
    subclassMustImplement()
  }

  func mutate(with mutation: Mutation<State>) {
    subclassMustImplement()
  }

  func scoped<S, E>(
    to scope: WritableKeyPath<State, S>,
    event: @escaping (E) -> Event
  ) -> StoreBoxBase<S, E> {
    subclassMustImplement()
  }
}

@inline(never)
private func subclassMustImplement(function: StaticString = #function) -> Never {
  fatalError("Subclass must implement `\(function)`.")
}

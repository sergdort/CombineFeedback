import Combine
import SwiftUI

internal class RootStoreBox<State, Event>: StoreBoxBase<State, Event> {
  private let subject: CurrentValueSubject<State, Never>

  private let inputObserver: (Event) -> Void
  private var bag = Set<AnyCancellable>()

  override var _current: State {
    subject.value
  }

  override var publisher: AnyPublisher<State, Never> {
    subject.eraseToAnyPublisher()
  }

  public init<M: StateMachine>(
    initial: State,
    machine: M
  ) where M.State == State, M.Event == Event {
    let input = Feedback<State, Event>.input
    let resolved = machine._resolve()
    self.subject = CurrentValueSubject(initial)
    self.inputObserver = input.observer
    Publishers.FeedbackLoop(
      initial: initial,
      reduce: resolved.reducer,
      feedbacks: resolved.feedbacks.appending(input.feedback)
    )
    .sink(receiveValue: { [subject] state in
      subject.send(state)
    })
    .store(in: &bag)
  }

  override func send(event: Event) {
    self.inputObserver(event)
  }

  override func scoped<S, E>(
    getValue: @Sendable @escaping (State) -> S,
    event: @Sendable @escaping (E) -> Event
  ) -> StoreBoxBase<S, E> {
    ScopedStoreBox<State, Event, S, E>(
      parent: self,
      getValue: getValue,
      event: event
    )
  }
}

internal class ScopedStoreBox<RootState, RootEvent, ScopedState, ScopedEvent>: StoreBoxBase<ScopedState, ScopedEvent> {
  private let parent: StoreBoxBase<RootState, RootEvent>
  private let getValue: @Sendable (RootState) -> ScopedState
  private let eventTransform: @Sendable (ScopedEvent) -> RootEvent

  override var _current: ScopedState {
    getValue(parent._current)
  }

  override var publisher: AnyPublisher<ScopedState, Never> {
    parent.publisher.map(getValue).eraseToAnyPublisher()
  }

  init(
    parent: StoreBoxBase<RootState, RootEvent>,
    getValue: @Sendable @escaping (RootState) -> ScopedState,
    event: @Sendable @escaping (ScopedEvent) -> RootEvent
  ) {
    self.parent = parent
    self.getValue = getValue
    self.eventTransform = event
  }

  override func send(event: ScopedEvent) {
    parent.send(event: eventTransform(event))
  }

  override func scoped<S, E>(
    getValue: @Sendable @escaping (ScopedState) -> S,
    event: @Sendable @escaping (E) -> ScopedEvent
  ) -> StoreBoxBase<S, E> {
    let outerGetValue = self.getValue
    let outerEventTransform = self.eventTransform
    return ScopedStoreBox<RootState, RootEvent, S, E>(
      parent: self.parent) { rootState in
        getValue(outerGetValue(rootState))
      } event: { e in
        outerEventTransform(event(e))
      }
  }
}

internal class StoreBoxBase<State, Event> {
  /// Loop Internal SPI
  var _current: State { subclassMustImplement() }

  var publisher: AnyPublisher<State, Never> { subclassMustImplement() }

  func send(event: Event) {
    subclassMustImplement()
  }

  final func scoped<S, E>(
    to scope: WritableKeyPath<State, S>,
    event: @Sendable @escaping (E) -> Event
  ) -> StoreBoxBase<S, E> {
    let box = SendableKeyPath(keyPath: scope)
    return self.scoped(
      getValue: { state in
        return state[keyPath: box.keyPath]
      },
      event: event
    )
  }

  func scoped<S, E>(
    getValue: @Sendable @escaping (State) -> S,
    event: @Sendable @escaping (E) -> Event
  ) -> StoreBoxBase<S, E> {
    subclassMustImplement()
  }
}

// Key paths are immutable metadata, so sharing one across threads is safe.
// The wrapper keeps key-path projections free of non-Sendable captures.
private struct SendableKeyPath<Root, Value>: @unchecked Sendable {
  let keyPath: WritableKeyPath<Root, Value>
}

@inline(never)
private func subclassMustImplement(function: StaticString = #function) -> Never {
  fatalError("Subclass must implement `\(function)`.")
}

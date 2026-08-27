import Combine
import CombineSchedulers
import SwiftUI

@propertyWrapper
@MainActor
public struct StoreBinding<State, Event>: DynamicProperty {
  @ObservedObject
  private var subscription: StoreBindingSubscription<State, Event>
  private let store: Store<State, Event>

  public var wrappedValue: State {
    subscription.latestValue
  }

  public var projectedValue: StoreBinding<State, Event> {
    self
  }

  public init(
    _ store: Store<State, Event>,
    removeDuplicates isDuplicate: @escaping @Sendable (State, State) -> Bool
  ) {
    self.store = store
    self.subscription = StoreBindingSubscription(store: store, removeDuplicates: isDuplicate)
  }

  public func send(_ event: Event) {
    store.send(event: event)
  }

  public func binding<Value>(
    for keyPath: KeyPath<State, Value>,
    event: @escaping (Value) -> Event
  ) -> Binding<Value> {
    Binding(
      get: {
        self.wrappedValue[keyPath: keyPath]
      },
      set: {
        self.send(event($0))
      }
    )
  }

  public func binding<Value>(
    for keyPath: KeyPath<State, Value>,
    event: Event
  ) -> Binding<Value> {
    Binding(
      get: {
        self.wrappedValue[keyPath: keyPath]
      },
      set: { _ in
        self.send(event)
      }
    )
  }

  public func action(for event: Event) -> () -> Void {
    {
      self.send(event)
    }
  }

  public func scoped<ScopedState, ScopedEvent>(
    to value: @escaping (State) -> ScopedState,
    event: @escaping (ScopedEvent) -> Event,
    removeDuplicates isDuplicate: @escaping @Sendable (ScopedState, ScopedState) -> Bool
  ) -> StoreBinding<ScopedState, ScopedEvent> {
    StoreBinding<ScopedState, ScopedEvent>(
      store.scope(getValue: value, event: event),
      removeDuplicates: isDuplicate
    )
  }
}

public extension StoreBinding where State: Equatable & Sendable {
  init(_ store: Store<State, Event>) {
    self.init(store, removeDuplicates: { $0 == $1 })
  }
}

public extension StoreBinding {
  func scoped<ScopedState, ScopedEvent>(
    to value: @escaping (State) -> ScopedState,
    event: @escaping (ScopedEvent) -> Event
  ) -> StoreBinding<ScopedState, ScopedEvent> where ScopedState: Equatable & Sendable {
    scoped(to: value, event: event, removeDuplicates: { $0 == $1 })
  }
}

@MainActor
private final class StoreBindingSubscription<State, Event>: ObservableObject {
  @Published
  private(set) var latestValue: State
  private var bag = Set<AnyCancellable>()

  init(
    store: Store<State, Event>,
    removeDuplicates isDuplicate: @escaping @Sendable (State, State) -> Bool
  ) {
    self.latestValue = store.state
    store.publisher
      .removeDuplicates(by: isDuplicate)
      .receive(on: UIScheduler.shared, options: nil)
      .assign(to: \.latestValue, weakly: self)
      .store(in: &bag)
  }
}

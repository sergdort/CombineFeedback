import SwiftUI
import Combine
import CombineSchedulers

@available(*, deprecated, renamed: "ViewContext")
public typealias Context<State, Event> = ViewContext<State, Event>

@dynamicMemberLookup
public final class ViewContext<State, Event>: ObservableObject {
  @Published
  private var state: State
  private var bag = Set<AnyCancellable>()
  private let send: (Event) -> Void

  init(
    store: StoreBoxBase<State, Event>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool
  ) {
    self.state = store._current
    self.send = store.send
    store.publisher
      .removeDuplicates(by: isDuplicate)
      .receive(on: UIScheduler.shared, options: nil)
      .assign(to: \.state, weakly: self)
      .store(in: &bag)
  }

  public subscript<U>(dynamicMember keyPath: KeyPath<State, U>) -> U {
    return state[keyPath: keyPath]
  }

  public func send(event: Event) {
    send(event)
  }

  public func binding<U>(for keyPath: KeyPath<State, U>, event: @escaping (U) -> Event) -> Binding<U> {
    return Binding(
      get: {
        self.state[keyPath: keyPath]
      },
      set: {
        self.send(event: event($0))
      }
    )
  }

  public func binding<U>(for keyPath: KeyPath<State, U>, event: Event) -> Binding<U> {
    return Binding(
      get: {
        self.state[keyPath: keyPath]
      },
      set: { _ in
        self.send(event: event)
      }
    )
  }

  public func action(for event: Event) -> () -> Void {
    return {
      self.send(event: event)
    }
  }
}

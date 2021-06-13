import Combine
import CombineFeedback
import Foundation
import CasePaths

open class Store<State, Event> {
  private let box: StoreBoxBase<State, Event>

  public var state: State {
    box._current
  }

  var publisher: AnyPublisher<State, Never> {
    box.publisher
  }

  init(box: StoreBoxBase<State, Event>) {
    self.box = box
  }

  public init(
    initial: State,
    feedbacks: [Feedback<State, Event>],
    reducer: Reducer<State, Event>
  ) {
    self.box = RootStoreBox(
      initial: initial,
      feedbacks: feedbacks,
      reducer: reducer
    )
  }

  @MainActor func context(
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool
  ) -> ViewContext<State, Event> {
    ViewContext(store: box, removeDuplicates: isDuplicate)
  }

  open func send(event: Event) {
    box.send(event: event)
  }

  open func mutate<V>(keyPath: WritableKeyPath<State, V>, value: V) {
    box.mutate(keyPath: keyPath, value: value)
  }

  open func mutate(with mutation: Mutation<State>) {
    box.mutate(with: mutation)
  }

  public func scoped<S, E>(
    to scope: WritableKeyPath<State, S>,
    event: @escaping (E) -> Event
  ) -> Store<S, E> {
    return Store<S, E>(box: box.scoped(to: scope, event: event))
  }
}

public struct Mutation<State> {
  let mutate: (inout State) -> Void

  init<V>(keyPath: WritableKeyPath<State, V>, value: V) {
    self.mutate = { state in
      state[keyPath: keyPath] = value
    }
  }

  init(mutate: @escaping (inout State) -> Void) {
    self.mutate = mutate
  }
}

extension Array {
  func appending(_ element: Element) -> [Element] {
    var copy = self

    copy.append(element)

    return copy
  }
}

public extension Publisher where Self.Failure == Never {
  func assign<Root: AnyObject>(
    to keyPath: WritableKeyPath<Root, Self.Output>, weakly object: Root
  ) -> AnyCancellable {
    return self.sink { [weak object] output in
      object?[keyPath: keyPath] = output
    }
  }
}

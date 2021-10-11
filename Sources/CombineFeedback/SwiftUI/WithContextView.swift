import Combine
import SwiftUI

@available(*, deprecated, renamed: "WithContextView")
public typealias Widget<State, Event, Content: View> = WithContextView<State, Event, Content>

/// A helper view that bridges Store into SwiftUI world by using @ObservedObject ViewContext
/// to listed to the state changes of the Store and render the UI
public struct WithContextView<State, Event, Content: View>: View {
  @ObservedObject
  private var context: ViewContext<State, Event>
  private let store: Store<State, Event>
  private let content: (ViewContext<State, Event>) -> Content

  public init(
    store: Store<State, Event>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool,
    @ViewBuilder content: @escaping (ViewContext<State, Event>) -> Content
  ) {
    self.store = store
    self.content = content
    self.context = store.context(removeDuplicates: isDuplicate)
  }

  public var body: some View {
    return content(context)
  }
}

public extension WithContextView where State: Equatable {
  init(
    store: Store<State, Event>,
    @ViewBuilder content: @escaping (ViewContext<State, Event>) -> Content
  ) {
    self.init(store: store, removeDuplicates: ==, content: content)
  }
}

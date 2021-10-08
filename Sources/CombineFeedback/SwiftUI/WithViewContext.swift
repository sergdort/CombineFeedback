import Combine
import SwiftUI

@available(*, deprecated, renamed: "WithViewContext")
public typealias Widget<State, Event, Content: View> = WithViewContext<State, Event, Content>

public struct WithViewContext<State, Event, Content: View>: View {
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

public extension WithViewContext where State: Equatable {
  init(
    store: Store<State, Event>,
    @ViewBuilder content: @escaping (ViewContext<State, Event>) -> Content
  ) {
    self.init(store: store, removeDuplicates: ==, content: content)
  }
}

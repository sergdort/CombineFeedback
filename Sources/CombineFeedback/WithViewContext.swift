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

public struct IfLetWithViewContext<State, Event, Content: View>: View {
  private let store: Store<State?, Event>
  private let content: (ViewContext<State?, Event>) -> Content


  public init<IfContent: View, ElseContent: View>(
    store: Store<State?, Event>,
    @ViewBuilder then ifContent: @escaping (Store<State, Event>) -> IfContent,
    @ViewBuilder else elseContent: @escaping () -> ElseContent
  ) where Content == _ConditionalContent<IfContent, ElseContent> {
    self.store = store
    self.content = { context in
      if let state = context[dynamicMember: \State.self] {
        return ViewBuilder.buildEither(
          first: ifContent(
            store.scope(
              getValue: {
                return $0 ?? state
              }, setValue: { state, s in
                state = s
              }
            )
          )
        )
      } else {
        return ViewBuilder.buildEither(second: elseContent())
      }
    }
  }

  public init<IfContent: View>(
    store: Store<State?, Event>,
    @ViewBuilder then ifContent: @escaping (Store<State, Event>) -> IfContent
  ) where Content == _ConditionalContent<IfContent, EmptyView> {
    self.init(store: store, then: ifContent, else: EmptyView.init)
  }

  public var body: some View {
    WithViewContext(
      store: self.store,
      removeDuplicates: { ($0 != nil) == ($1 != nil) },
      content: content
    )
  }
}

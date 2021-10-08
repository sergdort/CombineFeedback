import SwiftUI

public struct IfLetStoreView<State, Event, Content: View>: View {
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
                $0 ?? state
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

import SwiftUI

public struct IfLetStoreView<State, Event, Content: View>: View {
  private let store: Store<State?, Event>
  @StoreBinding<State?, Event> private var state: State?
  private let content: (State?) -> Content

  public init<IfContent: View, ElseContent: View>(
    store: Store<State?, Event>,
    @ViewBuilder then ifContent: @escaping (Store<State, Event>) -> IfContent,
    @ViewBuilder else elseContent: @escaping () -> ElseContent
  ) where Content == _ConditionalContent<IfContent, ElseContent> {
    self.store = store
    self._state = StoreBinding(
      store,
      removeDuplicates: { @Sendable in ($0 != nil) == ($1 != nil) }
    )
    self.content = { state in
      if let state {
        return ViewBuilder.buildEither(
          first: ifContent(
            store.scope(
              getValue: {
                return $0 ?? state
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
    content(state)
  }
}

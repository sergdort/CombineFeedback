import SwiftUI

/// Implementation taken from TCA
public struct SwitchStoreView<State, Event, Content: View>: View {
  public let store: Store<State, Event>
  public let content: () -> Content

  init(
    store: Store<State, Event>,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.store = store
    self.content = content
  }

  public var body: some View {
    self.content()
      .environmentObject(StoreObservableObject(store: self.store))
  }
}

public struct CaseLetStoreView<GlobalState, GlobalEvent, LocalState, LocalEvent, Content: View>: View {
  @EnvironmentObject private var store: StoreObservableObject<GlobalState, GlobalEvent>
  public let toLocalState: WritableKeyPath<GlobalState, LocalState?>
  public let fromLocalEvent: (LocalEvent) -> GlobalEvent
  public let content: (Store<LocalState, LocalEvent>) -> Content

  public init(
    state toLocalState: WritableKeyPath<GlobalState, LocalState?>,
    action fromLocalEvent: @escaping (LocalEvent) -> GlobalEvent,
    @ViewBuilder then content: @escaping (Store<LocalState, LocalEvent>) -> Content
  ) {
    self.toLocalState = toLocalState
    self.fromLocalEvent = fromLocalEvent
    self.content = content
  }

  public var body: some View {
    IfLetStoreView(
      store: self.store.wrappedValue.scoped(to: toLocalState, event: fromLocalEvent),
      then: self.content
    )
  }
}

private class StoreObservableObject<State, Event>: ObservableObject {
  let wrappedValue: Store<State, Event>

  init(store: Store<State, Event>) {
    self.wrappedValue = store
  }
}

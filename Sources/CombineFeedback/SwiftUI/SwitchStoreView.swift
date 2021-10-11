import SwiftUI
import CasePaths

/// A view that can switch over a store of enum state and handle each case.
///
/// An application may model parts of its state with enums. For example, app state may differ if a
/// user is logged-in or not:
///
/// ```swift
/// enum AppState {
///   case loggedIn(LoggedInState)
///   case loggedOut(LoggedOutState)
/// }
/// ```
/// Gives compile time guaranties that all cases of the enum State can be handled
///```swift
/// SwitchStoreView(store: store) { state in
///   switch state {
///     case .loggedIn:
///       CaseLetStoreView(state: /AppState.loggedIn, action: Event.loggedIn) { store in
///         LoggedInView(store: store)
///       }
///     case .loggedOut:
///       CaseLetStoreView(state: /AppState.loggedOut, action: AppState.loggedOut) { store in
///         SignInView(store: store)
///       }
///   }
/// }
public struct SwitchStoreView<State, Event, Content>: View where Content: View {
  private let store: Store<State, Event>
  private let content: (State) -> Content
  private let removeDuplicates: (State, State) -> Bool

  public init(
    store: Store<State, Event>,
    removeDuplicates: @escaping (State, State) -> Bool,
    @ViewBuilder content: @escaping (State) -> Content
  ) {
    self.store = store
    self.removeDuplicates = removeDuplicates
    self.content = content
  }

  public var body: some View {
    WithContextView(store: store, removeDuplicates: removeDuplicates) { context in
      self.content(context[dynamicMember: \State.self])
    }
    .environmentObject(StoreObservableObject(store: self.store))
  }
}

extension SwitchStoreView where State: Equatable {
  public init(
    store: Store<State, Event>,
    @ViewBuilder content: @escaping (State) -> Content
  ) {
    self.init(store: store, removeDuplicates: ==, content: content)
  }
}

/// Implementation is taken and adapted from the TCA
/// A convenient view helper that lets you match cases of the ``SwitchStoreView`` state
public struct CaseLetStoreView<GlobalState, GlobalEvent, LocalState, LocalEvent, Content: View>: View {
  @EnvironmentObject private var store: StoreObservableObject<GlobalState, GlobalEvent>
  public let toLocalState: (GlobalState) -> LocalState?
  public let fromLocalEvent: (LocalEvent) -> GlobalEvent
  public let content: (Store<LocalState, LocalEvent>) -> Content

  public init(
    state toLocalState: @escaping (GlobalState) -> LocalState?,
    action fromLocalEvent: @escaping (LocalEvent) -> GlobalEvent,
    @ViewBuilder then content: @escaping (Store<LocalState, LocalEvent>) -> Content
  ) {
    self.toLocalState = toLocalState
    self.fromLocalEvent = fromLocalEvent
    self.content = content
  }

  public var body: some View {
    IfLetStoreView(
      store: self.store.wrappedValue
        .scope(
          getValue: toLocalState,
          event: fromLocalEvent
        ),
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

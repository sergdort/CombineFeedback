import Foundation
import CombineFeedback
import Combine
import CasePaths
import SwiftUI

enum SwitchStoreExample {
  struct RootView: View {
    let store: Store<State, Event>

    var body: some View {
      SwitchStoreView(store: store) { state in
        switch state {
        case .signIn:
          CaseLetStoreView(state: /State.signIn, action: Event.signIn) { store in
            SignInView(store: store)
          }
        case .counter:
          CaseLetStoreView(state: /State.counter, action: Event.counter) { store in
            CounterView(store: store)
          }
        }
      }
    }
  }

  static var reducer: Reducer<State, Event> {
    Reducer.combine(
      SignIn.reducer()
        .pullback(
          value: /State.signIn,
          event: /Event.signIn
        ),
      Counter.reducer()
        .pullback(
          value: /State.counter,
          event: /Event.counter
        ),
      Reducer(reduce: Self.innerReducer(state:event:))
    )
  }

  static var feedbacks: Feedback<State, Event, Dependencies> {
    .combine(
      SignIn.feedback.pullback(
        value: /State.signIn,
        event: /Event.signIn,
        dependency: \.signIn
      )
    )
  }

  private static func innerReducer(state: inout State, event: Event) {
    switch event {
    case .signIn(.didSignIn):
      state = .counter(Counter.State())
    default:
      break
    }
  }

  enum State: Equatable {
    case signIn(SignIn.State)
    case counter(Counter.State)
  }

  enum Event {
    case signIn(SignIn.Event)
    case counter(Counter.Event)
  }

  struct Dependencies {
    var signIn: SignIn.Dependencies
  }
}

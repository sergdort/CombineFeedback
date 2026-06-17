import CombineFeedback
import CasePaths
import SwiftUI

struct SwitchStoreExample: StateMachine {
  let dependencies: Dependencies

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

  @StateMachineBuilder<State, Event>
  var body: some StateMachine<State, Event> {
    Scope<State, Event, Machine<SignIn.State, SignIn.Event>>(
      state: /State.signIn,
      event: /Event.signIn
    ) {
      SignIn(dependencies: dependencies.signIn)
    }

    Scope<State, Event, Machine<Counter.State, Counter.Event>>(
      state: /State.counter,
      event: /Event.counter
    ) {
      Counter()
    }

    Reducer(reduce: Self.innerReducer(state:event:))
  }

  private static func innerReducer(state: inout State, event: Event) {
    switch event {
    case .signIn(.didSignIn):
      state = .counter(Counter.State())
    default:
      break
    }
  }
}

struct SwitchStoreExampleView: View {
  let store: Store<SwitchStoreExample.State, SwitchStoreExample.Event>

  var body: some View {
    SwitchStoreView(store: store) { state in
      switch state {
      case .signIn:
        CaseLetStoreView(state: /SwitchStoreExample.State.signIn, action: SwitchStoreExample.Event.signIn) { store in
          SignInView(store: store)
        }
      case .counter:
        CaseLetStoreView(state: /SwitchStoreExample.State.counter, action: SwitchStoreExample.Event.counter) { store in
          CounterView(store: store)
        }
      }
    }
  }
}

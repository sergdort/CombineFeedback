import CasePaths
import Combine
import CombineFeedback
import CombineFeedbackTest
import XCTest

@CasePathable
private enum SyncCheckEvent: Equatable, Sendable {
  case start
  case setPage(Int)
  case logPage(Int)
}

private struct SyncEventCheckMachine: StateMachine {
  struct State: Equatable {
    var logged: [Int] = []
  }

  @StateMachineBuilder<State, SyncCheckEvent>
  var body: some StateMachine<State, SyncCheckEvent> {
    Reducer<State, SyncCheckEvent> { state, event in
      if case let .logPage(value) = event {
        state.logged.append(value)
      }
    }
    eventFeedback
  }

  var eventFeedback: OnEvent<State, SyncCheckEvent, Void> {
    OnEvent(\.start) { () -> SyncCheckEvent in
      .logPage(42)
    }
  }
}

private struct SyncPayloadCheckMachine: StateMachine {
  struct State: Equatable {
    var logged: [Int] = []
  }

  var reducer: Reducer<State, SyncCheckEvent> {
    Reducer { state, event in
      switch event {
      case .start, .setPage:
        break
      case let .logPage(value):
        state.logged.append(value)
      }
    }
  }

  var feedback: OnEvent<State, SyncCheckEvent, Int> {
    OnEvent(\.setPage) { (value: Int) -> SyncCheckEvent in
      .logPage(value * 2)
    }
  }

  @StateMachineBuilder<State, SyncCheckEvent>
  var body: some StateMachine<State, SyncCheckEvent> {
    reducer
    feedback
  }
}

private struct SyncChangeCheckMachine: StateMachine {
  struct State: Equatable {
    var page = 0
    var logged: [Int] = []
  }

  var reducer: Reducer<State, SyncCheckEvent> {
    Reducer { state, event in
      switch event {
      case .start:
        break
      case let .setPage(value):
        state.page = value
      case let .logPage(value):
        state.logged.append(value)
      }
    }
  }

  var feedback: OnChange<State, SyncCheckEvent, Int> {
    OnChange(of: { (state: State) -> Int in state.page }) { (value: Int) -> SyncCheckEvent in
      .logPage(value)
    }
  }

  @StateMachineBuilder<State, SyncCheckEvent>
  var body: some StateMachine<State, SyncCheckEvent> {
    reducer
    feedback
  }
}

final class SyncOverloadResolutionTests: XCTestCase {
  func testSyncVoidEventClosureResolvesAndRuns() async {
    let store = TestStore(initial: SyncEventCheckMachine.State(), machine: SyncEventCheckMachine())

    store.send(.start)
    await store.wait { $0.logged == [42] }

    XCTAssertEqual(store.state.logged, [42])
  }

  func testSyncPayloadEventClosureResolvesAndRuns() async {
    let store = TestStore(
      initial: SyncPayloadCheckMachine.State(),
      machine: SyncPayloadCheckMachine()
    )

    store.send(.setPage(21))
    await store.wait { $0.logged == [42] }

    XCTAssertEqual(store.state.logged, [42])
  }

  func testSyncChangeClosureResolvesAndRuns() async {
    let store = TestStore(
      initial: SyncChangeCheckMachine.State(),
      machine: SyncChangeCheckMachine()
    )

    store.send(.start)
    await store.wait { $0.logged == [0] }
    XCTAssertEqual(store.state.logged, [0])

    store.send(.setPage(3))
    await store.wait { $0.logged == [0, 3] }
    XCTAssertEqual(store.state.logged, [0, 3])
  }

  func testPublisherClosureStillBindsToPublisherOverload() {
    let machine = OnEvent<Void, SyncCheckEvent, Int>(\.logPage) { (value: Int) -> Just<SyncCheckEvent> in
      Just(.logPage(value))
    }
    _ = machine._resolve()
  }

  func testAsyncClosureStillResolves() {
    let machine = OnEvent<Void, SyncCheckEvent, Void>(\.start) { () async -> SyncCheckEvent in
      .start
    }
    _ = machine._resolve()
  }
}

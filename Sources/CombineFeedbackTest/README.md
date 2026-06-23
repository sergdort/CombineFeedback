# CombineFeedbackTest

Ergonomic testing for CombineFeedback state machines.

`CombineFeedbackTest` drives the **real** `Store` and feedback loop, with
dependencies mocked through your machine's initializer, and lets you assert by
**waiting for the state the user would observe**.

## Philosophy: test the destination, not the journey

A `TestStore` test answers one question: *given these events, did the system
arrive at the state the user would see, and did it call the dependencies it
should have?*

- **Destination, not journey.** You assert the states that are real product
  requirements (a spinner appears, then data loads), not every intermediate
  transition. Tests stay readable and survive refactors of *how* the machine
  gets there.
- **Side effects are asserted by your mocks.** Inject stubs/spies through the
  machine's initializer and assert on them (e.g. "fetch was called once").
- **Real loop, high fidelity.** The reducer *and* the feedbacks run, so a test
  catches mis-wired feedbacks (wrong key path, wrong event), not just reducer
  logic.

## Setup

Add the product to your test target:

```swift
.testTarget(
  name: "MyFeatureTests",
  dependencies: [
    "MyFeature",
    .product(name: "CombineFeedbackTest", package: "CombineFeedback"),
  ]
)
```

## API

```swift
let store = TestStore(initial: State, machine: SomeMachine)

store.send(_ event: Event)                              // drive the loop
await store.wait(timeout:until:) { state in Bool }      // suspend until a state is reached
store.state                                             // the current state
```

- `wait` completes the **instant** the loop reaches a matching state — with
  immediate mocks that's microseconds.
- `timeout` defaults to **100ms** and is per-call overridable. A passing test
  never spends it; the timeout only fires when a machine never arrives (a real
  bug), reporting a failure at the call site.

## A worked example

A fetch + pagination machine, with `fetch` mocked through the initializer:

```swift
struct Movies: StateMachine {
  let fetch: (Int) async throws -> [Movie]
  // ... State (idle / loading / loaded), Event, reducer, OnChange(of: \.nextPage) ...
}

func test_appearing_loads_movies() async {
  let store = TestStore(
    initial: Movies.State(),
    machine: Movies(fetch: { page in [Movie(id: page)] })   // immediate mock
  )

  store.send(.fetchNext)
  await store.wait { $0.status == .idle && !$0.movies.isEmpty }

  XCTAssertEqual(store.state.movies, [Movie(id: 1)])
}
```

No `State: Equatable` requirement is imposed by the framework — `wait` works on
a predicate. (You'll often want `Equatable` for your own `XCTAssertEqual`.)

## Three ways to test

The journey-states you care about are simply destinations you choose to `wait`
for. How many you pin is the only difference between these styles.

### 1. Destination — assert the end state

```swift
store.send(.fetchNext)
await store.wait { $0.status == .idle && !$0.movies.isEmpty }
```

### 2. Ordered waypoints — pin the states that are real requirements

Sequential `wait`s enforce order; intermediate states you don't name stay
invisible and refactorable. Useful when "show a spinner before data" is a
genuine requirement:

```swift
store.send(.fetchNext)
await store.wait { $0.status == .loading }   // the spinner must appear...
await store.wait { $0.status == .idle }      // ...before data lands

store.send(.retry)
await store.wait { $0.status == .idle && !$0.movies.isEmpty }
```

### 3. Asserting side effects

The framework asserts *state*; your injected mock asserts *calls*:

```swift
let calls = LockedCount()
let store = TestStore(
  initial: Movies.State(),
  machine: Movies(fetch: { page in calls.increment(); return [Movie(id: page)] })
)

store.send(.fetchNext)
await store.wait { $0.status == .idle }
XCTAssertEqual(calls.value, 1)   // debounced/deduped exactly once
```

## How `wait` reports failures

When a predicate is never satisfied before `timeout`, `wait` reports a test
issue **at the call site** via
[swift-issue-reporting](https://github.com/pointfreeco/swift-issue-reporting),
so it surfaces natively in both **XCTest** and **Swift Testing** — no `try`
required. The message includes the last state and the **observed trajectory**
(rendered with [swift-custom-dump](https://github.com/pointfreeco/swift-custom-dump)),
so you can see where the machine got stuck:

```
wait(until:) timed out after 100ms — predicate never satisfied.
  Last state: Movies.State(status: .loading, movies: [])
  Observed trajectory:
    Movies.State(status: .idle, movies: [])
    Movies.State(status: .loading, movies: [])   ← stuck here; the mock never resolved?
```

The trajectory is recorded only for diagnostics; it never affects a passing
test.

## Time, schedulers and clocks

`TestStore` is **clock-agnostic** — controlling time is your concern, not the
framework's. For debounce / throttle / polling, inject a scheduler or clock
through the machine's initializer and advance it in the test:

```swift
let scheduler = DispatchQueue.test          // from combine-schedulers
let store = TestStore(
  initial: Search.State(),
  machine: Search(fetch: ..., scheduler: scheduler.eraseToAnyScheduler())
)

store.send(.queryChanged("sw"))
store.send(.queryChanged("swift"))
scheduler.advance(by: .milliseconds(300))   // advance BEFORE you await...
await store.wait { $0.results.isEmpty == false }   // ...or wait parks before time moves
```

> **Order matters:** advance the scheduler *before* `await store.wait(...)`. A
> `wait` suspends the test, so any `advance` written after it never runs and the
> wait will simply time out.

## Notes

- The timeout default (100ms) is generous enough to absorb executor jitter on
  loaded CI while still failing fast on a genuinely stuck machine. Bump it
  per-call if needed.
- `TestStore` is `Sendable` and drives the production `Store`, so anything you
  can express in production you can test here.

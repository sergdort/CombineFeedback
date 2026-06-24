---
name: combinefeedback-state-machine-testing
description: Use whenever writing, changing, or reviewing tests for app logic built with the CombineFeedback Swift library. For designing or refactoring the machines themselves, use the combinefeedback-state-machines skill instead.
metadata:
  short-description: Test CombineFeedback state machines.
---

# Testing CombineFeedback State Machines

Verifying a CombineFeedback machine means proving it honors its transition and
invariant contract and arrives at the states a user would observe, with
dependencies replaced by test doubles.

This skill is for agents helping library consumers; do not assume access to the
CombineFeedback source repository.

If the work is about modeling state, events, reducers, or feedback lifecycles —
not verifying them — defer to the companion skill `combinefeedback-state-machines`.

## Core Stance: Test The Destination, Not The Journey

A test answers one question: *given these events, did the system arrive at the
state the user would see, and did it call the dependencies it should have?*

- **Destination, not journey.** Assert the states that are real product
  requirements (a spinner appears, then data loads), not every intermediate
  transition. Tests stay readable and survive refactors of *how* the machine
  gets there.
- **Side effects are asserted by test doubles.** Substitute test doubles for
  dependencies using whatever injection approach the app already uses, and assert
  on them ("fetch was called once"). The harness asserts *state*; the double
  asserts *calls*.
- **The contract is the spec.** The design skill produces a transition/invariant
  contract. Tests verify that contract — they are not a transcript of the
  implementation.

## Scope

Do not give SwiftUI/store-binding guidance or generic test-framework setup under
this skill — both are out of scope.

## Verify Before Compile-Ready Code

CombineFeedback APIs may vary by installed version. Before producing
compile-ready tests in a consumer app, confirm the testing facility is available
and inspect its surface. The destination-testing API ships in a separate product,
`CombineFeedbackTest`, which the test target must depend on:

```swift
.testTarget(
  name: "MyFeatureTests",
  dependencies: [
    "MyFeature",
    .product(name: "CombineFeedbackTest", package: "CombineFeedback"),
  ]
)
```

Current primitives to expect:

- `TestStore(initial:machine:)`: wraps the real `Store` and feedback loop.
- `store.send(_ event:)`: drives the loop exactly as production would.
- `await store.wait(timeout:until:)`: suspends until a state predicate holds;
  default timeout is short (≈100ms) and fails fast at the call site.
- `store.state`: the current state.
- `Reducer` is `public` with `callAsFunction`, so a reducer exposed as a property
  can be invoked directly and synchronously in a test.

If version details are uncertain, keep snippets conceptual and confirm the API
against the installed package before presenting them as compile-ready.

## Two Tiers Of Verification

Match the test to the thing being proven. Most machines want both tiers.

### Tier 1 — Reducer Transition Tests (pure, synchronous, exhaustive)

The reducer is a pure `(inout State, Event) -> Void`. When the machine exposes it
as a property, drive it directly: no async, no feedback, microsecond tests that
can exhaustively cover the transition table.

```swift
func test_didLoad_appends_and_returns_to_idle() {
  var state = Movies.State(status: .loading)
  Movies.reducer(&state, .didLoad([Movie(id: 1)]))   // exposed as a property
  XCTAssertEqual(state.status, .idle)
  XCTAssertEqual(state.movies, [Movie(id: 1)])
}
```

Use Tier 1 to pin the **transition table and reducer invariants** from the design
contract. It exercises only the reducer — never the feedback wiring — so it does
not prove effects are connected correctly.

Exposing the reducer as a `static`/`var` property is the small encapsulation cost
of getting this tier. If the consumer prefers not to expose it, fold those cases
into Tier 2.

### Tier 2 — TestStore Destination Tests (real loop, high fidelity)

`TestStore` drives the real `Store` *and* feedbacks, with the machine's
dependencies replaced by test doubles. This is the only tier that catches
mis-wired feedbacks (wrong key path, wrong event), which is where most real bugs
live.

```swift
func test_fetchNext_loads_movies() async {
  let store = TestStore(
    initial: Movies.State(),
    machine: Movies(fetch: { page in [Movie(id: page)] })   // immediate stub
  )

  store.send(.fetchNext)
  await store.wait { $0.status == .idle && !$0.movies.isEmpty }

  XCTAssertEqual(store.state.movies, [Movie(id: 1)])
}
```

This example injects the double through the initializer for brevity. If the app
resolves dependencies another way — a dependency container, a `@Dependency`-style
property wrapper, an overridable global — substitute the double through *that*
mechanism instead; the skill is agnostic to how injection happens.

`wait` completes the **instant** the predicate holds (microseconds with immediate
stubs); the timeout only elapses when a machine never arrives — a real bug — and
then reports a failure at the call site.

## TestStore Workflow

1. Set up the machine with **test doubles** for its dependencies, using the app's
   existing injection approach. Use immediate stubs so the loop settles instantly;
   use spies when you need to assert calls.
2. `send` the event(s) under test.
3. `wait { ... }` for the user-observable destination state.
4. Assert on `store.state` for data, and on your test double for side effects.

### Substitute Dependencies With Test Doubles

Establish the doubles up front, however the app injects dependencies — initializer
parameters, a dependency container, a property wrapper. Do not swap behavior
partway through a test. The example below injects through the initializer, but the
principle holds for any injection mechanism.

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

### Ordered Waypoints When Order Is A Requirement

Sequential `wait`s enforce order. Pin only the states that are genuine
requirements ("a spinner must show before data"); unnamed intermediate states
stay invisible and refactorable.

```swift
store.send(.fetchNext)
await store.wait { $0.status == .loading }   // the spinner must appear...
await store.wait { $0.status == .idle }      // ...before data lands
```

### Time Is The Consumer's Concern

`TestStore` is clock-agnostic. For debounce / throttle / polling, the machine
takes a scheduler or clock as one of its dependencies; in the test, supply a
controllable one through the same injection mechanism and advance it. Advance
**before** you await — a `wait` suspends the test, so any `advance` written after
it never runs and the wait times out.

```swift
let scheduler = DispatchQueue.test
let store = TestStore(initial: .init(), machine: Search(fetch: ..., scheduler: scheduler.eraseToAnyScheduler()))

store.send(.queryChanged("swift"))
scheduler.advance(by: .milliseconds(300))          // advance BEFORE awaiting
await store.wait { !$0.results.isEmpty }
```

## What To Test

- **Destinations that are product requirements.** The states a user observes:
  loaded data, empty state, error surfaced, form enabled/disabled.
- **Invariants from the design contract.** E.g. "work exists only when
  `State.request` is non-nil", "success and failure are mutually exclusive".
- **Dependency interactions.** Called the right number of times, with the right
  arguments, and *not* called when it should not be (e.g. debounce coalesced).
- **Feedback wiring (Tier 2 only).** Entering a state starts the effect; leaving
  it cancels/replaces the effect.

## What Not To Test

- **Every intermediate transition** that is not itself a requirement. That
  couples the test to the implementation path and breaks on refactor.
- **Feedback internals or scheduling mechanics.** Assert the observable
  destination, not how many times a publisher ticked.
- **Impossible states the type system already prevents.** If the model makes a
  state unrepresentable, no test is needed for it.
- **Real network, disk, or wall-clock time.** Mock the dependency; inject the
  clock. A test that needs a real delay is a mis-designed test.

## Failure Diagnostics

When a predicate is never satisfied before `timeout`, `wait` reports a test issue
**at the call site** (surfacing in both XCTest and Swift Testing) with the last
state and the **observed trajectory**, so it is clear where the machine got stuck:

```text
wait(until:) timed out after 100ms — predicate never satisfied.
  Last state: Movies.State(status: .loading, movies: [])
  Observed trajectory:
    Movies.State(status: .idle, movies: [])
    Movies.State(status: .loading, movies: [])   ← stuck; the mock never resolved?
```

A stuck `wait` almost always means one of: the mock never returns, the feedback
is wired to the wrong key path/event, or a scheduler was not advanced. Read the
trajectory before changing the test — it usually names the bug.

## Required Output Shape

When this skill is used to plan tests for a machine, end with a concise test plan
containing these sections.

### Tier 1 — Reducer Cases

List the transition-table rows worth pinning directly, and whether the reducer is
exposed for direct invocation (or needs to be).

### Tier 2 — Destination Scenarios

For each scenario: the event(s) sent, the destination predicate to `wait` for,
and the state assertions afterward.

```text
Scenario: first page loads
- send: .fetchNext
- wait: status == .idle && !movies.isEmpty
- assert: movies == [Movie(id: 1)]
```

### Mocks And Spies

For each injected dependency: the stub behavior and what is asserted about its
calls.

```text
fetch: returns [Movie(id: page)] immediately; assert called exactly once.
```

### Time Control

State whether the machine needs a test scheduler/clock and where it is injected.

### Open Verification Questions

Ask only questions that change what is asserted, such as:

- Is "spinner before data" a real requirement (ordered waypoint) or incidental?
- Should a stale response after cancellation be ignored, and must a test prove it?
- Is the debounce window itself a contract worth a scheduler-advance test?

## Traps To Avoid

- `sleep`/`wait(for:)`-style fixed delays instead of `await store.wait { ... }`.
- Using a long timeout to paper over a stuck machine — fix the wiring, not the
  budget.
- Treating a green Tier 1 reducer test as proof the feature works — feedback
  wiring stays unverified until a Tier 2 test exercises it.

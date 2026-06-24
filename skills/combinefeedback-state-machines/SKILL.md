---
name: combinefeedback-state-machines
description: Use whenever building, changing, or reviewing app logic that uses the CombineFeedback Swift library.
metadata:
  short-description: Build with CombineFeedback.
---

# CombineFeedback State Machines

Use this skill when designing or refining application logic built with the Swift
CombineFeedback library. Focus on modeling state machines: state boundaries,
events, reducers, feedback lifecycles, and reusable child machines.

This skill is for agents helping library consumers. Do not assume access to the
CombineFeedback source repository. Respect the user's app architecture, existing
agent instructions, and any state machines already defined in the app.

## Scope

Use this skill for:

- Designing a new CombineFeedback feature state machine.
- Splitting a large state machine into smaller machines.
- Refactoring recurring lifecycle behavior into reusable child machines.
- Choosing between `OnEvent`, `OnChange`, `SideEffect`, and `Feedback.custom`.
- Producing a machine decomposition sketch and transition/invariant contract.

Do not use this skill for:

- SwiftUI/store binding guidance.
- Testing strategy or test-store patterns (use the companion skill
  `combinefeedback-state-machine-testing`).
- Generic finite-state-machine theory unrelated to CombineFeedback.

If the user is exploring or refactoring, proactively challenge state boundaries
and look for reusable lifecycle machines. If the user is already implementing an
agreed plan, do not reopen architecture unless the plan conflicts with
CombineFeedback's model.

## Verify Before Compile-Ready Code

CombineFeedback APIs may vary by installed version. Before producing
compile-ready code in a consumer app, inspect the local package version, docs, or
source if available. For design sketches, use current CombineFeedback vocabulary
but keep snippets conceptual when version details are uncertain.

Current primitives to expect:

- `StateMachine`: composes reducers and feedbacks into a behavior.
- `State`: the single source of truth for the machine.
- `Event`: external inputs and feedback-produced occurrences.
- `Reducer`: pure state transition logic, usually `(inout State, Event) -> Void`.
- `Feedback`: observes state/event streams and emits events.
- `OnChange`: runs latest/cancellable effects from changes in derived state.
- `OnEvent`: runs latest effects from a specific event stream.
- `SideEffect`: fire-and-forget async work that does not emit events.
- `Feedback.custom`: escape hatch for advanced stream or cancellation behavior.
- `Scope` and `IfLet`: compose child machines into parent machines.

In CombineFeedback, reducers mutate state only; feedbacks observe state/events
and emit events back into the loop.

## Design Workflow

When asked to design or improve a CombineFeedback machine, work in this order:

1. Identify the behavior boundary.
2. Separate recurring lifecycle behavior from feature-specific policy.
3. Choose `State` shape using enums for exclusive modes and structs for
   orthogonal facts.
4. Name public `Event` cases for user intent, external input, and effect results.
5. Put all state transitions in reducers.
6. Decide which feedback primitive owns each effect lifecycle.
7. Compose reusable child machines with explicit child state and child event cases.
8. End with a decomposition sketch and a lightweight transition/invariant
   contract.

Do not require broad repository reconnaissance. Use the context already provided
by the user. Inspect targeted files only when needed to avoid inventing APIs,
duplicating an existing reusable machine, or violating local naming/style.

## Modeling Rules

### Events Trigger Intent, State Owns Lifecycle

Use `OnEvent` when an effect is a direct reaction to an external event and the
effect's lifetime is tied only to that event stream.

Use reducer -> lifecycle/request state -> `OnChange` when the system must start,
cancel, or replace work as state changes. This is the default for loading,
pagination, validation, polling, retry, and debounced search lifecycles.

Examples:

- A button tap that should fire analytics: `SideEffect`.
- A one-off event-local async command: `OnEvent`.
- A fetch that should cancel when leaving `.fetching`: reducer sets state,
  `OnChange` observes derived request state.
- A polling loop that starts on appear and stops on disappear: reducer sets a
  polling mode, `OnChange` observes that mode.

### Make Impossible States Unrepresentable

Use sum types for mutually exclusive lifecycle modes:

```swift
enum State {
  case idle
  case fetching(Params)
  case success(Success)
  case failure(ErrorState)
}
```

Avoid modeling one lifecycle as independent `isLoading`, `value?`, `error?`, and
`request?` fields. Those combinations create invalid states the reducer must
defend manually.

Use product types for facts that can coexist:

```swift
struct State {
  var query: String
  var selectedFilter: Filter
  var results: Fetch<SearchResults, SearchRequest>.State
}
```

Do not store values that can be derived from state. Derive request state from the
mode that owns it:

```swift
extension Fetch.State {
  var request: Params? {
    guard case let .fetching(params) = self else { return nil }
    return params
  }
}
```

### Prefer Reusable Machines For Recurring Lifecycle Behavior

Reusable child machines are a good fit for behavior like:

- Fetching one resource.
- Pagination.
- Username or form-field validation.
- Debounced search.
- Polling.
- Retry/backoff lifecycle.

Keep one-off feature policy local to the feature. Do not extract a reusable
machine if its public API would leak parent-specific concepts or create more glue
than clarity.

Reusable child machines should own their lifecycle policy and the effect needed
to fulfill it. Inject dependencies through the machine initializer:

```swift
struct Fetch<Success, Params>: StateMachine {
  let fetch: (Params) async throws -> Success
}
```

The parent supplies concrete services when composing the child.

### Compose Child Machines Explicitly

When a parent owns a reusable child machine, expose child state and child events
explicitly so `Scope` can route them:

```swift
struct MoviesScreen: StateMachine {
  struct State {
    var movies: Fetch<MoviePage, Page>.State
    var selectedMovieID: Movie.ID?
  }

  enum Event {
    case movies(Fetch<MoviePage, Page>.Event)
    case movieTapped(Movie.ID)
  }
}
```

Parent-specific events can still translate into child events when that is the
clearest domain API, but do not manually duplicate child lifecycle state in the
parent.

## Choosing Feedback Primitives

Use this decision rule:

- `OnChange`: state-driven lifecycle. Entering a state starts work; leaving or
  changing the derived request cancels/replaces work.
- `OnEvent`: direct reaction to an event stream. Good for external triggers when
  no durable lifecycle state needs to own cancellation.
- `SideEffect`: fire-and-forget work that cannot emit events, such as analytics
  or logging.
- `Feedback.custom`: advanced stream coordination not expressible with
  `OnChange`, `OnEvent`, or `SideEffect`.

Prefer `OnChange` for effect lifecycles that are part of the state machine's
meaning. Prefer `OnEvent` only when modeling the effect as durable state would be
artificial.

## Canonical Concept: Fetch

Use `Fetch` as the canonical reusable lifecycle example. This is conceptual
Swift-like pseudo-code, not a drop-in generic implementation.

```swift
struct Fetch<Success, Params>: StateMachine where Params: Equatable {
  let fetch: (Params) async throws -> Success

  enum State {
    case idle
    case fetching(Params)
    case success(Success)
    case failure(ErrorState)

    var request: Params? {
      guard case let .fetching(params) = self else { return nil }
      return params
    }
  }

  enum Event {
    case fetch(Params)
    case cancel
    case response(Result<Success, ErrorState>)
  }

  var body: some StateMachine<State, Event> {
    Reducer { state, event in
      switch event {
      case let .fetch(params):
        state = .fetching(params)

      case .cancel:
        state = .idle

      case let .response(.success(value)):
        state = .success(value)

      case let .response(.failure(error)):
        state = .failure(error)
      }
    }

    OnChange(of: \.request) { params in
      do {
        return .response(.success(try await fetch(params)))
      } catch {
        return .response(.failure(ErrorState(error)))
      }
    }
  }
}
```

Important modeling points:

- `.fetch(params)` is still an event. Events express public intent.
- `.fetching(params)` is lifecycle state. State owns whether work should exist.
- `request` is derived, not stored separately.
- `OnChange` gives latest/cancellation behavior when `request` changes or becomes
  `nil`.
- `.cancel` cancels by moving state to a mode whose derived request is `nil`.
- Stale response handling can be added with request identity if the local effect
  source is non-cooperative or can emit after cancellation, but do not make that
  complexity the default V1 pattern.

## Required Output Shape

When this skill is used for design work, end with a concise design sketch that
contains these sections.

### Machine Decomposition

List each machine and its ownership:

```text
MoviesScreen
- Owns screen-specific selection and presentation policy.
- Composes Fetch<MoviePage, Page> for page loading.

Fetch<MoviePage, Page>
- Owns loading lifecycle and fetch dependency.
- Emits response events back into its own reducer.
```

### State Shape

Show the proposed state structure and call out which parts are exclusive modes
versus orthogonal facts.

### Event Contract

List public intent events, child events, and feedback result events. Prefer
literal domain names for user/external events and clear result names for effect
outputs.

### Feedback Plan

For each effect, state which primitive owns it and why:

```text
Fetch request: OnChange(of: State.request)
Reason: fetch lifetime follows .fetching(params); cancel is represented by
leaving .fetching.
```

### Transition And Invariant Contract

Use a lightweight contract, not a huge table:

```text
Fetch transitions
- idle + fetch(params) -> fetching(params)
- fetching + cancel -> idle
- fetching + response(.success(value)) -> success(value)
- fetching + response(.failure(error)) -> failure(error)
- success/failure + fetch(params) -> fetching(params)

Invariants
- Work exists only when State.request is non-nil.
- request is derived from .fetching, never stored independently.
- success and failure are mutually exclusive modes.
```

### Open Modeling Questions

Ask only questions that affect the state machine boundary or lifecycle, such as:

- Should success data remain visible while refreshing?
- Should cancellation return to `.idle` or preserve previous content?
- Is pagination a separate child machine or part of the screen's domain policy?
- Can the effect source emit after cancellation, requiring request identity?

## Model-Level Traps To Avoid

Avoid warnings that the API already prevents. Focus on traps the type system and
library cannot fully prevent:

- Boolean/optional soup for a lifecycle that should be an enum.
- Stored request flags that duplicate derived state.
- `OnEvent` for work that must cancel when state leaves a mode.
- Reusable machines that leak parent-specific policy.
- Giant screen machines that hide recurring lifecycle submachines.
- Reopening architecture when the user has already supplied an agreed plan.

import CombineFeedback
import CombineFeedbackTest
import XCTest
@testable import Example

final class ExampleTests: XCTestCase {}

/// Exercises the real `Movies` state machine (fetch + pagination + retry) with a
/// stubbed `fetchMovies` dependency, using the `CombineFeedbackTest` TestStore.
final class MoviesTestStoreTests: XCTestCase {
  private func movie(_ id: Int) -> Movie {
    Movie(id: id, overview: "overview \(id)", title: "Title \(id)", posterPath: nil)
  }

  private func results(page: Int, _ movies: [Movie]) -> Results {
    Results(page: page, totalResults: movies.count, totalPages: 10, results: movies)
  }

  func test_fetchNext_reaches_loaded() async throws {
    let store = TestStore(
      initial: Movies.State(batch: .empty(), movies: [], status: .idle),
      machine: Movies(dependencies: .init(fetchMovies: { [self] page in
        results(page: page, [movie(page * 10)])
      }))
    )

    store.send(.fetchNext)
    await store.wait { $0.status == .idle && !$0.movies.isEmpty }

    XCTAssertEqual(store.state.movies, [movie(10)])
  }

  // Sequential waypoints (style 3) on the real machine — paginate twice.
  func test_pagination_appends_in_order() async throws {
    let store = TestStore(
      initial: Movies.State(batch: .empty(), movies: [], status: .idle),
      machine: Movies(dependencies: .init(fetchMovies: { [self] page in
        results(page: page, [movie(page)])
      }))
    )

    store.send(.fetchNext)
    await store.wait { $0.movies == [movie(1)] }

    store.send(.fetchNext)
    await store.wait { $0.movies == [movie(1), movie(2)] }
  }

  // Failure -> retry -> loaded. The destination is asserted, not the path.
  func test_retry_after_failure() async throws {
    let shouldFail = LockedFlag(true)
    let store = TestStore(
      initial: Movies.State(batch: .empty(), movies: [], status: .idle),
      machine: Movies(dependencies: .init(fetchMovies: { [self] page in
        if shouldFail.swap(false) {
          throw NSError(domain: "test", code: 1)
        }
        return results(page: page, [movie(page * 10)])
      }))
    )

    store.send(.fetchNext)
    await store.wait { if case .failed = $0.status { return true } else { return false } }

    store.send(.retry)
    await store.wait { $0.status == .idle && $0.movies == [movie(10)] }
  }
}

private final class LockedFlag: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Bool
  init(_ value: Bool) { self.value = value }
  func swap(_ next: Bool) -> Bool {
    lock.lock(); defer { lock.unlock() }
    let old = value
    value = next
    return old
  }
}

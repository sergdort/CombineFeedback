import Foundation
import CombineFeedback
import Combine

enum Movies {
  struct Dependencies {
    var movies: (Int) async throws -> Results
    var fetchMovies: (Int) -> AnyPublisher<Results, NSError>
  }

  struct State: Equatable {
    var batch: Results
    var movies: [Movie]
    var status: Status

    var nextPage: Int? {
      switch status {
      case .loading:
        return batch.page + 1
      case .failed:
        return nil
      case .idle:
        return nil
      }
    }

    var error: NSError? {
      switch status {
      case .failed(let error):
        return error
      default:
        return nil
      }
    }

    enum Status: Equatable {
      case idle
      case loading
      case failed(NSError)
    }
  }

  enum Event {
    case didLoad(Results)
    case didFail(NSError)
    case retry
    case fetchNext
  }

  static func reducer() -> Reducer<State, Event> {
    .init { state, event in
      switch event {
      case .didLoad(let batch):
        state.movies += batch.results
        state.status = .idle
        state.batch = batch
      case .didFail(let error):
        state.status = .failed(error)
      case .retry:
        state.status = .loading
      case .fetchNext:
        state.status = .loading
      }
    }
  }

  static var feedback: Feedback<State, Event, Dependencies> {
    if #available(iOS 15.0, *) {
      return .lensing(state: \.nextPage) { page, dependency in
        do {
          return Event.didLoad(try await URLSession.shared.movies(page: page))
        } catch {
          return Event.didFail(error as NSError)
        }
      }
    } else {
      return .lensing(state: { $0.nextPage }) { page, dependency in
        dependency.fetchMovies(page)
          .map(Event.didLoad)
          .replaceError(replace: Event.didFail)
          .receive(on: DispatchQueue.main)
      }
    }
  }
}

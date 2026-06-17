import Foundation
import CombineFeedback
import Combine

struct Movies: StateMachine {
  let dependencies: Dependencies

  struct Dependencies {
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
    case didLike(Movie, index: Int)
  }

  @StateMachineBuilder<State, Event>
  var body: some StateMachine<State, Event> {
    reducer
    feedback
  }

  var reducer: Reducer<State, Event> {
    Reducer { state, event in
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
      case .didLike(_, let index):
        state.movies[index].isFavourite = !state.movies[index].isFavourite
      }
    }
  }

  var feedback: Feedback<State, Event> {
    Feedback.custom { input, output in
      input.changes(of: \.nextPage)
        .flatMapLatest { page -> AnyPublisher<Never, Never> in
          guard let page else { return Empty().eraseToAnyPublisher() }

          return dependencies.fetchMovies(page)
            .map(Event.didLoad)
            .replaceError(replace: Event.didFail)
            .receive(on: DispatchQueue.main)
            .enqueue(to: output)
            .eraseToAnyPublisher()
        }
    }
  }
}

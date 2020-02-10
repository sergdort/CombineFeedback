import Foundation
import CombineFeedback

enum Movies {
    struct State: Builder {
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

        enum Status {
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

    static func reducer(state: State, event: Event) -> State {
        switch event {
        case .didLoad(let batch):
            return state.set(\.batch, batch)
                .set(\.movies, state.movies + batch.results)
                .set(\.status, .idle)
        case .didFail(let error):
            return state.set(\.status, .failed(error))
        case .retry:
            return state
                .set(\.status, .loading)
        case .fetchNext:
            return state
                .set(\.status, .loading)
        }
    }

    static var feedback: Feedback<State, Event> {
        return Feedback(lensing: { $0.nextPage }) { page in
            URLSession.shared
                .fetchMovies(page: page)
                .map(Event.didLoad)
                .replaceError(replace: Event.didFail)
                .receive(on: DispatchQueue.main)
        }
    }

}

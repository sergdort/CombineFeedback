import Foundation
import CombineFeedback

enum Movies {
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

    static func reducer(state: inout State, event: Event) {
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

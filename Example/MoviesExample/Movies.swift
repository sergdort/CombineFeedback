import Combine
import CombineFeedback
import CombineFeedbackUI
import Foundation
import SwiftUI

final class MoviesViewModel: ViewModel<MoviesViewModel.State, MoviesViewModel.Event> {
    let initial = MoviesViewModel.State(
        batch: Results.empty(),
        movies: [],
        status: .loading
    )
    var feedbacks: [Feedback<State, Event>] {
        return [
            MoviesViewModel.whenLoading()
        ]
    }

    init() {
        super.init(
            initial: initial,
            feedbacks: [MoviesViewModel.whenLoading()],
            scheduler: DispatchQueue.main,
            reducer: MoviesViewModel.reducer(state:event:)
        )
    }

    private static func reducer(state: State, event: Event) -> State {
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

    private static func whenLoading() -> Feedback<State, Event> {
        return Feedback(lensing: { $0.nextPage }) { page in
            URLSession.shared
                .fetchMovies(page: page)
                .map(Event.didLoad)
                .replaceError(replace: Event.didFail)
        }
    }

    enum Event {
        case didLoad(Results)
        case didFail(NSError)
        case retry
        case fetchNext
    }

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
    }

    enum Status {
        case idle
        case loading
        case failed(NSError)
    }
}

struct MoviesView: View {
    typealias State = MoviesViewModel.State
    typealias Event = MoviesViewModel.Event
    let context: Context<State, Event>

    var body: some View {
        List {
          ForEach(context.movies, id:\.id) { movie in
                NavigationLink(destination: Widget(viewModel: MoviesViewModel(), render: MoviesView.init)) {
                    MovieCell(movie: movie).onAppear {
                        if self.context.movies.last == movie {
                            self.context.send(event: .fetchNext)
                        }
                    }
                }
            }
        }
    }
}

struct MovieCell: View {
    @Environment(\.imageFetcher) var fetcher: ImageFetcher
    var movie: Movie

    private var poster: AnyPublisher<UIImage, Never> {
        return fetcher.image(for: movie.posterURL)
    }

    var body: some View {
        return HStack {
            AsyncImage(
                source: poster,
                placeholder: UIImage(systemName: "film")!
            )
            .frame(width: 77, height: 130)
            .clipped()
            Text(movie.title).font(.title)
        }
    }
}

struct Results: Codable {
    let page: Int
    let totalResults: Int
    let totalPages: Int
    let results: [Movie]

    static func empty() -> Results {
        return Results(page: 0, totalResults: 0, totalPages: 0, results: [])
    }

    enum CodingKeys: String, CodingKey {
        case page
        case totalResults = "total_results"
        case totalPages = "total_pages"
        case results
    }
}

struct Movie: Codable, Equatable {
    let id: Int
    let overview: String
    let title: String
    let posterPath: String?

    var posterURL: URL {
        return posterPath
            .map {
                "https://image.tmdb.org/t/p/w154\($0)"
            }
            .flatMap(URL.init(string:))!
    }

    enum CodingKeys: String, CodingKey {
        case id
        case overview
        case title
        case posterPath = "poster_path"
    }
}

let correctAPIKey = "d4f0bdb3e246e2cb3555211e765c89e3"
var shouldFail = false

func switchFail() {
    shouldFail = !shouldFail
}

extension URLSession {
    func fetchMovies(page: Int) -> AnyPublisher<Results, NSError> {
        let url = URL(string: "https://api.themoviedb.org/3/discover/movie?api_key=\(shouldFail ? "" : correctAPIKey)&sort_by=popularity.desc&page=\(page)")!
        let request = URLRequest(url: url)

        return dataTaskPublisher(for: request)
            .map { $0.data }
            .decode(type: Results.self, decoder: JSONDecoder())
            .mapError { (error) -> NSError in
                error as NSError
            }
            .eraseToAnyPublisher()
    }
}

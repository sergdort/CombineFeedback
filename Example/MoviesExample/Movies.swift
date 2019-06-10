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
            reducer: MoviesViewModel.reducer(state:event:)
        )
    }

    private static func reducer(state: State, event: Event) -> State {
        switch event {
        case .didLoad(let batch):
            var copy = state

            copy.batch = batch
            copy.movies += batch.results
            copy.status = .idle

            return copy
        case .didFail(let error):
            var copy = state

            copy.status = .failed(error)

            return copy
        case .retry:
            var copy = state

            copy.status = .loading

            return copy
        case .fetchNext:
            var copy = state

            copy.status = .loading

            return copy
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

    struct State {
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

struct MoviesRenderer: Renderer {
    typealias State = MoviesViewModel.State
    typealias Event = MoviesViewModel.Event
    private let imageFetcher = ImageFetcher()

    func render(state: State, callback: Callback<Event>) -> AnyView {
        if let error = state.error, state.movies.isEmpty {
            return renderError(error, callback: callback)
        }
        return renderMovies(state.movies, callback: callback)
    }

    private func renderError(_ error: Error, callback: Callback<Event>) -> AnyView {
        return VStack {
            Text(error.localizedDescription)
            Button(action: {
                callback.send(event: .retry)
            }) {
                Text("Retry")
            }
        }
        .padding()
        .eraseToAnyView()
    }

    private func renderMovies(_ movies: [Movie], callback: Callback<Event>) -> AnyView {
        return List {
            ForEach(movies.identified(by: \.id)) { movie -> AnyView in
                if movies.last == movie {
                    return MovieCell(movie: movie)
                        .onAppear {
                            // Fetch next batch every time reach to the end of the list
                            callback.send(event: .fetchNext)
                        }
                        .eraseToAnyView()
                }
                return MovieCell(movie: movie)
                    .eraseToAnyView()
            }
        }
        .environmentObject(ConstBindable(value: imageFetcher))
        .eraseToAnyView()
    }
}

struct MovieCell: View {
    @EnvironmentObject private var fetcher: ConstBindable<ImageFetcher>
    var movie: Movie

    private var poster: AnyPublisher<UIImage, Never> {
        return fetcher.value.image(for: movie.posterURL)
    }

    var body: some View {
        return HStack {
            AsyncImage(source: poster, placeholder: UIImage(systemName: "film")!)
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

extension JSONDecoder: TopLevelDecoder {}

extension URLSession {
    func fetchMovies(page: Int) -> AnyPublisher<Results, NSError> {
        let url = URL(string: "https://api.themoviedb.org/3/discover/movie?api_key=\(shouldFail ? "" : correctAPIKey)&sort_by=popularity.desc&page=\(page)")!
        let request = URLRequest(url: url)

        return send(request: request)
            .map { $0.data }
            .decode(type: Results.self, decoder: JSONDecoder())
            .mapError { (error) -> NSError in
                error as NSError
            }
            .eraseToAnyPublisher()
    }
}

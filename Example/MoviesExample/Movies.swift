import Foundation
import Combine
import CombineFeedback
import CombineFeedbackUI
import SwiftUI

struct MoviesSystem: System {
    let initial = MoviesSystem.State(
        batch: Results.empty(),
        movies: [],
        status: .loading
    )
    var feedbacks: [Feedback<State, Event>] {
        return [
            MoviesSystem.whenLoading()
        ]
    }

    func reducer(state: State, event: Event) -> State {
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
        }
    }

    private static func whenLoading() -> Feedback<State, Event> {
        return Feedback(lensing: { $0.nextPage }) { (page) in
            return URLSession.shared
                .fetchMovies(page: page)
                .map(Event.didLoad)
                .replaceError(replace: Event.didFail)
        }
    }

    enum Event {
        case didLoad(Results)
        case didFail(NSError)
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
    }
    enum Status {
        case idle
        case loading
        case failed(NSError)
    }
}














struct MoviesRenderer: Renderer {
    typealias State = MoviesSystem.State
    typealias Event = MoviesSystem.Event

    func render(state: State, callback: Callback<Event>) -> AnyView {
        List {
            ForEach(state.movies) { (movie) in
                MovieCell(movie: movie)
            }
        }
        .eraseToAnyView()
    }
}

struct MovieCell: View {
    var movie: Movie

    var body: some View {
        return Text(movie.title)
    }
}

struct Results: Codable {
    let page: Int
    let totalResults: Int
    let totalPages: Int
    let results: [Movie]

    static func empty() -> Results {
        return Results.init(page: 0, totalResults: 0, totalPages: 0, results: [])
    }

    enum CodingKeys: String, CodingKey {
        case page
        case totalResults = "total_results"
        case totalPages = "total_pages"
        case results
    }
}

struct Movie: Codable {
    let id: Int
    let overview: String
    let title: String
    let posterPath: String?

    var posterURL: URL? {
        return posterPath
            .map {
                "https://image.tmdb.org/t/p/w342/\($0)"
            }
            .flatMap(URL.init(string:))
    }

    enum CodingKeys: String, CodingKey {
        case id
        case overview
        case title
        case posterPath = "poster_path"
    }
}

extension Movie: Identifiable {}

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

        return self.send(request: request)
            .map { $0.data }
            .decode(type: Results.self, decoder: JSONDecoder())
            .mapError { (error) -> NSError in
                return error as NSError
            }
            .eraseToAnyPublisher()
    }
}

extension Publisher {
    public func replaceError(
        replace: @escaping (Failure) -> Self.Output
    ) -> AnyPublisher<Self.Output, Never> {
        return self.catch { error in
            return Publishers.Just(replace(error))
        }.eraseToAnyPublisher()
    }
}

enum RequestError: Error {
    case request(code: Int, error: Error?)
    case unknown
}

extension URLSession {
    func send(request: URLRequest) -> Publishers.Future<(data: Data, response: HTTPURLResponse), RequestError> {
        return Publishers.Future { (promise) in
            self.dataTask(with: request) { (data, response, error) in
                let httpReponse = response as? HTTPURLResponse
                if let data = data, let httpReponse = httpReponse, 200..<300 ~= httpReponse.statusCode {
                    promise(Result.success((data, httpReponse)))
                } else if let httpReponse = httpReponse {
                    promise(.failure(.request(code: httpReponse.statusCode, error: error)))
                } else {
                    promise(.failure(.unknown))
                }
            }
            .resume()
        }
    }
}

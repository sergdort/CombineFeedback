import Combine
import CombineFeedback
import CombineFeedbackUI
import Foundation
import SwiftUI

extension Movies {
  final class ViewModel: Store<Movies.State, Movies.Event> {
    let initial = Movies.State(
      batch: Results.empty(),
      movies: [],
      status: .loading
    )
    var feedbacks: [Feedback<State, Event>] {
      if #available(iOS 15.0, *) {
        return [
          ViewModel.whenLoadingIOS15()
        ]
      } else {
        return [
          ViewModel.whenLoading()
        ]
      }
    }

    init() {
      super.init(
        initial: initial,
        feedbacks: [ViewModel.whenLoading()],
        reducer: Movies.reducer()
      )
    }

    private static func whenLoading() -> Feedback<State, Event> {
      .lensing(state: { $0.nextPage }) { page in
        URLSession.shared
          .fetchMovies(page: page)
          .map(Event.didLoad)
          .replaceError(replace: Event.didFail)
          .receive(on: DispatchQueue.main)
      }
    }

    @available(iOS 15.0, *)
    private static func whenLoadingIOS15() -> Feedback<State, Event> {
      .lensing(state: \.nextPage) { page in
        do {
          return Event.didLoad(try await URLSession.shared.movies(page: page))
        } catch {
          return Event.didFail(error as NSError)
        }
      }
    }
  }
}

struct MoviesView: View {
  typealias State = Movies.State
  typealias Event = Movies.Event
  let store: Store<State, Event>

  init(store: Store<State, Event>) {
    self.store = store
    logInit(of: self)
  }

  var body: some View {
    logBody(of: self)
    return WithViewContext(store: store) { context in
      List {
        ForEach(context.movies) { movie in
          MovieCell(movie: movie).onAppear {
            if context.movies.last == movie {
              context.send(event: .fetchNext)
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
    return movie.posterURL.map(fetcher.image)
      .default(to: Empty().eraseToAnyPublisher())
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

struct Results: Codable, Equatable {
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

struct Movie: Codable, Equatable, Identifiable {
  let id: Int
  let overview: String
  let title: String
  let posterPath: String?

  var posterURL: URL? {
    return posterPath
      .map {
        "https://image.tmdb.org/t/p/w154\($0)"
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

  @available(iOS 15.0, *)
  func movies(page: Int) async throws -> Results {
    let url = URL(string: "https://api.themoviedb.org/3/discover/movie?api_key=\(shouldFail ? "" : correctAPIKey)&sort_by=popularity.desc&page=\(page)")!
    let request = URLRequest(url: url)
    let decoder = JSONDecoder()
    let (data, _) = try await self.data(for: request, delegate: nil)
    return try decoder.decode(Results.self, from: data)
  }
}

extension Optional {
  func `default`(to value: Wrapped) -> Wrapped {
    return self ?? value
  }
}

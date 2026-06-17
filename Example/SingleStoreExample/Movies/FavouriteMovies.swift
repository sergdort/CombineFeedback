import Foundation
import CombineFeedback
import CasePaths
import SwiftUI
import Combine

struct FavouriteMovies: StateMachine {
  let dependencies: Movies.Dependencies

  struct State: Equatable {
    var favouriteMovies: [Movie] = []
    var isNavigationActive: Bool = false
    var moviesState = Movies.State(batch: .empty(), movies: [], status: .loading)
  }

  enum Event {
    case movies(Movies.Event)
    case didChangeNavigation(Bool)
  }

  @StateMachineBuilder<State, Event>
  var body: some StateMachine<State, Event> {
    reducer

    Scope<State, Event, Machine<Movies.State, Movies.Event>>(state: \State.moviesState, event: /Event.movies) {
      Movies(dependencies: dependencies)
    }
  }

  var reducer: Reducer<State, Event> {
    Reducer { state, event in
      switch event {
      case let .movies(.didLike(movie, _)):
        if let index = state.favouriteMovies.firstIndex(where: { $0.id == movie.id }) {
          state.favouriteMovies.remove(at: index)
        } else {
          state.favouriteMovies.append(movie)
        }
      case let .didChangeNavigation(isActive):
        state.isNavigationActive = isActive
      default:
        break
      }
    }
  }
}

struct FavouriteMoviesView: View {
  @Environment(\.imageFetcher)
  private var fetcher: ImageFetcher

  var store: Store<FavouriteMovies.State, FavouriteMovies.Event>

  var body: some View {
    WithContextView(store: store) { context in
      ScrollView {
        if context.favouriteMovies.isEmpty {
          VStack {
            Button(action: context.action(for: FavouriteMovies.Event.didChangeNavigation(true))) {
              HStack {
                Image(systemName: "plus")
                Text("Select movies")
              }
            }
          }
        } else {
          LazyVGrid(
            columns: Array(
              repeating: GridItem(
                .adaptive(minimum: 200, maximum: 400),
                spacing: 8,
                alignment: .leading
              ),
              count: 3
            ),
            alignment: .leading,
            spacing: 8
          ) {
            ForEach(context.favouriteMovies) { movie in
              gridItem(movie: movie)
            }
          }
          .padding(.horizontal)
        }
      }
      .navigate(
        using: context.binding(for: \.isNavigationActive, event: FavouriteMovies.Event.didChangeNavigation)
      ) {
        MoviesView(store: store.scoped(to: \.moviesState, event: FavouriteMovies.Event.movies))
      }
      .navigationBarItems(
        leading: EmptyView(),
        trailing: Button(
          action: context.action(for: FavouriteMovies.Event.didChangeNavigation(true)),
          label: {
            Image(systemName: "plus")
          }
        )
      )
    }
  }

  func gridItem(movie: Movie) -> some View {
    AsyncImage(
      source: movie.posterURL.map(fetcher.image)
        .default(to: Empty().eraseToAnyPublisher()),
      placeholder: UIImage(systemName: "film")!
    ) { image in
      Image(uiImage: image)
        .resizable()
        .frame(width: 100)
        .aspectRatio(0.7, contentMode: .fill)
    }
  }
}

extension View {
  func navigate<Destination: View>(
    using binding: Binding<Bool>,
    @ViewBuilder destination: () -> Destination
  ) -> some View {
    background(NavigationLink(isActive: binding, destination: destination, label: EmptyView.init))
  }

  func background<Content: View>(@ViewBuilder _ builder: () -> Content) -> some View {
    background(builder())
  }
}

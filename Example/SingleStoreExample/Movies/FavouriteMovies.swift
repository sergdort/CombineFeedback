import Foundation
import CombineFeedback
import CasePaths
import SwiftUI
import Combine

enum FavouriteMovies {
  struct RootView: View {
    @Environment(\.imageFetcher)
    private var fetcher: ImageFetcher
    
    var store: Store<State, Event>

    var body: some View {
      WithContextView(store: store) { context in
        ScrollView {
          if context.favouriteMovies.isEmpty {
            VStack {
              Button(action: context.action(for: Event.didChangeNavigation(true))) {
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
          using: context.binding(for: \.isNavigationActive, event: Event.didChangeNavigation)
        ) {
          MoviesView(store: store.scoped(to: \.moviesState, event: Event.movies))
        }
        .navigationBarItems(
          leading: EmptyView(),
          trailing: Button(
            action: context.action(for: Event.didChangeNavigation(true)),
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

  struct State: Equatable {
    var favouriteMovies: [Movie] = []
    var isNavigationActive: Bool = false
    var moviesState = Movies.State(batch: .empty(), movies: [], status: .loading)
  }

  enum Event {
    case movies(Movies.Event)
    case didChangeNavigation(Bool)
  }

  static var reducer: Reducer<State, Event> {
    Reducer.combine(
      .init { state, event in
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
      },
      Movies.reducer()
        .pullback(
          state: \State.moviesState,
          event: /Event.movies
        )
    )
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

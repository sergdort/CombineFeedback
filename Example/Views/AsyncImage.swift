import SwiftUI
import Combine
import CombineFeedback

struct AsyncImage<Content: View>: View {
  private let image: SwiftUI.State<UIImage>
  private let source: AnyPublisher<UIImage, Never>
  private let content: (UIImage) -> Content

  init(
    source: AnyPublisher<UIImage, Never>,
    placeholder: UIImage,
    @ViewBuilder content: @escaping (UIImage) -> Content
  ) {
    self.source = source
    self.image = SwiftUI.State(initialValue: placeholder)
    self.content = content
  }

  var body: some View {
    return content(image.wrappedValue)
      .bind(source, to: image.projectedValue)
  }
}

extension View {
  func bind<P: Publisher, Value>(
    _ publisher: P,
    to state: Binding<Value>
  ) -> some View where P.Failure == Never, P.Output == Value {
    return onReceive(publisher) { value in
      state.wrappedValue = value
    }
  }
}

class ImageFetcher {
  private let cache = NSCache<NSURL, UIImage>()

  func image(for url: URL) -> AnyPublisher<UIImage, Never> {
    return Deferred { () -> AnyPublisher<UIImage, Never> in
      if let image = self.cache.object(forKey: url as NSURL) {
        return Result.Publisher(image)
          .eraseToAnyPublisher()
      }

      return URLSession.shared
        .dataTaskPublisher(for: url)
        .map { $0.data }
        .compactMap(UIImage.init(data:))
        .receive(on: DispatchQueue.main)
        .handleEvents(receiveOutput: { image in
          self.cache.setObject(image, forKey: url as NSURL)
        })
        .ignoreError()
    }
    .eraseToAnyPublisher()
  }
}

struct ImageFetcherKey: EnvironmentKey {
  static let defaultValue = ImageFetcher()
}

extension EnvironmentValues {
  var imageFetcher: ImageFetcher {
    get {
      return self[ImageFetcherKey.self]
    }
    set {
      self[ImageFetcherKey.self] = newValue
    }
  }
}

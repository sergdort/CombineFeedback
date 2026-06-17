import SwiftUI

struct AsyncImage<Content: View>: View {
  @Environment(\.imageFetcher)
  private var fetcher: ImageFetcher

  @State
  private var image: UIImage

  private let url: URL?
  private let placeholder: UIImage
  private let content: (UIImage) -> Content

  init(
    url: URL?,
    placeholder: UIImage,
    @ViewBuilder content: @escaping (UIImage) -> Content
  ) {
    self.url = url
    self.placeholder = placeholder
    self._image = State(initialValue: placeholder)
    self.content = content
  }

  var body: some View {
    content(image)
      .task(id: url) {
        guard let url else {
          image = placeholder
          return
        }

        image = await fetcher.image(for: url) ?? placeholder
      }
  }
}

class ImageFetcher {
  private let cache = NSCache<NSURL, UIImage>()

  func image(for url: URL) async -> UIImage? {
    if let image = cache.object(forKey: url as NSURL) {
      return image
    }

    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      guard let image = UIImage(data: data) else {
        return nil
      }
      cache.setObject(image, forKey: url as NSURL)
      return image
    } catch {
      return nil
    }
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

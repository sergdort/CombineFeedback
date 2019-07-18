import SwiftUI
import Combine
import CombineFeedback

struct AsyncImage: View {
    private let image: State<UIImage>
    private let source: AnyPublisher<UIImage, Never>
    private let animation: Animation?

    init(
        source: AnyPublisher<UIImage, Never>,
        placeholder: UIImage,
        animation: Animation? = nil
    ) {
        self.source = source
        self.image = State(initialValue: placeholder)
        self.animation = animation
    }

    var body: some View {
        return Image(uiImage: image.binding.value)
            .resizable()
            .bind(source, to: image.binding.animation(animation))
    }
}

extension View {
    func bind<P: Publisher, Value>(
        _ publisher: P,
        to state: Binding<Value>
    ) -> SubscriptionView<P, Self> where P.Failure == Never, P.Output == Value {
        return onReceive(publisher) { value in
            state.value = value
        }
    }
}

class ImageFetcher {
    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL) -> AnyPublisher<UIImage, Never> {
        return Deferred { () -> AnyPublisher<UIImage, Never> in
            if let image = self.cache.object(forKey: url as NSURL) {
                return Just(image)
                    .receive(on: DispatchQueue.main)
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
    static let defaultValue: ImageFetcher = ImageFetcher()
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

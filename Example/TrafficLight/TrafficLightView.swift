import SwiftUI
import CombineFeedback

struct TrafficLightView: View {
  let store: Store<TrafficLight.State, TrafficLight.Event>

  init(store: Store<TrafficLight.State, TrafficLight.Event>) {
    self.store = store
    logInit(of: self)
  }

  var body: some View {
    logBody(of: self)
    return WithContextView(store: store) { context in
      VStack {
        Circle()
          .fill(Color.red.opacity(context.isRed ? 1 : 0.5))
          .frame(width: 150, height: 150)
        Circle()
          .fill(Color.yellow.opacity(context.isYellow ? 1 : 0.5))
          .frame(width: 150, height: 150)
        Circle()
          .fill(Color.green.opacity(context.isGreen ? 1 : 0.5))
          .frame(width: 150, height: 150)
      }
      .padding()
      .background(Color.black)
    }
  }
}

#if DEBUG
struct TrafficLightView_Preview: PreviewProvider {
  static var previews: some View {
    TrafficLightView(
      store: .empty(.green)
    )
    .previewLayout(.sizeThatFits)
  }
}
#endif

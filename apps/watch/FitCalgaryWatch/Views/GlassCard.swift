import SwiftUI

struct GlassCard<Content: View>: View {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var contrast
  @ViewBuilder let content: Content
  init(@ViewBuilder content: () -> Content) { self.content = content() }
  var body: some View {
    Group {
      if reduceTransparency || contrast == .increased {
        content.padding(12)
          .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
          .overlay(RoundedRectangle(cornerRadius: 18).stroke(.primary.opacity(0.6)))
      } else if #available(watchOS 26.0, *) {
        content.padding(12).glassEffect(.regular, in: .rect(cornerRadius: 18))
      } else {
        content.padding(12)
          .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
          .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12)))
      }
    }
  }
}

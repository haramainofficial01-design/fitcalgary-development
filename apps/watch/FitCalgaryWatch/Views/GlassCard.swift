import SwiftUI

struct GlassCard<Content: View>: View {
  @ViewBuilder let content: Content
  init(@ViewBuilder content: () -> Content) { self.content = content() }
  var body: some View { Group { if #available(watchOS 26.0, *) { content.padding(12).glassEffect(.regular, in: .rect(cornerRadius: 18)) } else { content.padding(12).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12))) } } }
}

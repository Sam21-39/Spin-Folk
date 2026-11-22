import SwiftUI

extension View {
  /// Liquid Glass on iOS 26+, ultra-thin material before that. Same shape either way.
  @ViewBuilder
  func glassBackground<S: Shape>(_ shape: S) -> some View {
    if #available(iOS 26.0, *) {
      self.glassEffect(.regular, in: shape)
    } else {
      self.background(.ultraThinMaterial, in: shape)
    }
  }
}

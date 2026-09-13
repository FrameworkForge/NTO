import SwiftUI

/// The O motif preserves its status label when motion is disabled.
public struct NTOProgress: View {
  private let label: String
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var rotating = false
  public init(_ label: String) { self.label = label }
  public var body: some View {
    HStack(spacing: NTOTokens.Spacing.sm) {
      Circle()
        .trim(from: 0, to: 0.78)
        .stroke(NTOTokens.Color.paper, lineWidth: 2)
        .frame(width: 24, height: 24)
        .rotationEffect(.degrees(rotating && !reduceMotion ? 360 : 0))
        .animation(
          reduceMotion ? nil : .linear(duration: 1.2).repeatForever(autoreverses: false),
          value: rotating
        )
        .onAppear { rotating = true }
        .accessibilityHidden(true)
      Text(label).font(.caption)
    }
    .accessibilityElement(children: .combine)
  }
}

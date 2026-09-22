import SwiftUI

/// Keep the user's portrait size separate from the temporary space available in a pose.
struct CompositionLayoutMetrics {
    let size: CGSize
    let hasActiveDivision: Bool

    var isWide: Bool { size.width > size.height }
    var isLocked: Bool { isWide || hasActiveDivision }
    var maximumComposerHeight: CGFloat {
        // Reserve four playable rows, plus the handle and outer margins.
        max(0, min(max(190, size.height - 340), size.height - 232))
    }

    func composerHeight(preferred: CGFloat) -> CGFloat {
        min(max(0, preferred), maximumComposerHeight)
    }
}

struct AdaptiveCompositionLayout<Composer: View, Keypad: View, ResizeHandle: View>: View {
    let composerHeight: CGFloat
    @ViewBuilder var composer: () -> Composer
    @ViewBuilder var keypad: () -> Keypad
    @ViewBuilder var resizeHandle: (CGFloat) -> ResizeHandle

    var body: some View {
        if #available(iOS 27.1, *) {
            CompositionArrangement(
                composerHeight: composerHeight,
                composer: composer,
                keypad: keypad,
                resizeHandle: resizeHandle
            )
        } else {
            GeometryReader { geometry in
                let metrics = CompositionLayoutMetrics(size: geometry.size, hasActiveDivision: false)
                VStack(spacing: 0) {
                    composer()
                        .frame(height: metrics.composerHeight(preferred: composerHeight))
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                    resizeHandle(metrics.maximumComposerHeight)
                    keypad()
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                }
            }
        }
    }
}

@available(iOS 27.1, *)
private struct CompositionArrangement<Composer: View, Keypad: View, ResizeHandle: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let composerHeight: CGFloat
    @ViewBuilder var composer: () -> Composer
    @ViewBuilder var keypad: () -> Keypad
    @ViewBuilder var resizeHandle: (CGFloat) -> ResizeHandle

    var body: some View {
        GeometryReader { geometry in
            let divisions = geometry.reservedRegions(kind: .division)
            let metrics = CompositionLayoutMetrics(
                size: geometry.size,
                hasActiveDivision: !divisions.isEmpty
            )
            let primaryHeight: CGFloat? = metrics.isLocked
                ? nil : metrics.composerHeight(preferred: composerHeight) + 48

            // Keep both views in one arrangement throughout the transition. The system
            // owns the split axis, hinge margins, and displacement into usable regions.
            ArrangementView {
                VStack(spacing: 0) {
                    composer()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                        .padding(.bottom, metrics.isLocked ? 8 : 0)
                    resizeHandle(metrics.maximumComposerHeight)
                        .frame(height: metrics.isLocked ? 0 : 40)
                        .opacity(metrics.isLocked ? 0 : 1)
                        .allowsHitTesting(!metrics.isLocked)
                        .accessibilityHidden(metrics.isLocked)
                }
                .splitArrangementLayoutSize(
                    minHeight: primaryHeight,
                    idealHeight: primaryHeight,
                    maxHeight: primaryHeight
                )
            } secondary: {
                keypad()
                    .padding(.horizontal, 10)
                    .padding(.top, metrics.isLocked ? 8 : 0)
                    .padding(.bottom, 8)
            }
            .arrangementViewStyle(.split)
            // Animate pose changes, not note entry or direct manipulation of the handle.
            // The standard SwiftUI animation preserves continuity without a custom fold effect.
            .animation(reduceMotion ? nil : .default, value: metrics.isLocked)
            .animation(reduceMotion ? nil : .default, value: metrics.isWide)
            .animation(reduceMotion ? nil : .default, value: divisions)
        }
    }
}

struct AdaptiveNavigationTitle: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.modifier(VerticalBarNavigationTitle(title: title))
        } else {
            content.navigationTitle(title)
        }
    }
}

@available(iOS 27.1, *)
private struct VerticalBarNavigationTitle: ViewModifier {
    @Environment(\.toolbarVerticalEdge) private var toolbarEdge
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let title: String

    func body(content: Content) -> some View {
        // Outer portrait and inner landscape use vertical bars. An empty title
        // releases the horizontal title area while navigation/actions remain available.
        content.navigationTitle(toolbarEdge != nil || verticalSizeClass == .compact ? "" : title)
    }
}

import SwiftUI
import TimapCore

/// Top-level route. The popover is a single window; we navigate by swapping
/// the visible view, NOT by presenting `.sheet`. Sheets in `MenuBarExtra(.window)`
/// open a new NSWindow which steals key-window status — and when key-window
/// is lost the menu-bar popover is auto-dismissed by the system. The result
/// is "I close Settings → the whole app disappears", which we don't want.
enum Route: Equatable {
    case main
    case settings
}

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var route: Route = .main

    /// Header(60) + slider(50) + map+padding(218) + footer/spacing(20) ≈ 348.
    /// Each city card with chips runs ~88pt and the gap between cards is 8.
    /// We size for the visible city count, capped at 5 — past that the
    /// TeamRowsView's internal ScrollView absorbs the rest. The popover
    /// height is shared between main and settings so swapping routes
    /// doesn't bounce the menu-bar window.
    private static let baseHeight: CGFloat = 348
    private static let cardHeight: CGFloat = 88
    private static let cardGap: CGFloat = 8
    private static let rowsPadding: CGFloat = 22
    private static let maxCardsVisible = 5

    private var dynamicHeight: CGFloat {
        guard state.hasOnboarded else { return 640 }
        let count = state.citiesGrouped.count
        let n = max(1, min(Self.maxCardsVisible, count))
        return Self.baseHeight
            + CGFloat(n) * Self.cardHeight
            + CGFloat(max(0, n - 1)) * Self.cardGap
            + Self.rowsPadding
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: "#0d1420").ignoresSafeArea()

            if !state.hasOnboarded {
                OnboardingView()
            } else {
                switch route {
                case .main:
                    MainPanel(onOpenSettings: { route = .settings })
                case .settings:
                    SettingsView(onClose: { route = .main })
                }
            }
        }
        // Width fixed, height adapts to the visible city count (capped
        // at 5 cards). Both routes use the same height so the popover
        // doesn't jump when swapping main ↔ settings.
        .frame(width: 580, height: dynamicHeight)
        .animation(.easeInOut(duration: 0.18), value: dynamicHeight)
        .preferredColorScheme(.dark)
    }
}

private struct MainPanel: View {
    @EnvironmentObject var state: AppState
    var onOpenSettings: () -> Void

    var body: some View {
        // v11 vertical order: header → slider → map → city cards → footer.
        // The slider drives the map (light glow follows host hour) and the
        // map feeds context for the city cards below it.
        VStack(spacing: 0) {
            HeaderView(onOpenSettings: onOpenSettings)
            TimeSliderView()
            WorldMapView(
                hostHour: state.hostHour,
                hostOffsetHours: state.hostOffsetHours,
                hostDate: state.hostDate,
                hostInstant: state.hostInstant,
                cities: state.citiesGrouped.filter { !$0.isHidden }
            )
            // 580 popover - 24 horizontal padding = 556 width; at 2.7:1 the
            // map is ~206pt tall. Pin the height explicitly: SwiftUI's
            // aspectRatio modifier on Color collapses ambiguously when the
            // parent VStack has no fixed height (intrinsic-sized popover).
            .frame(height: 206)
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 8)

            TeamRowsView()
        }
        .background(Color(hex: "#0d1420"))
    }
}

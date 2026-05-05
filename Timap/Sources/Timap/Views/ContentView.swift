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
        // Width fixed, height intrinsic. Each route sizes to its own
        // content, and TeamRowsView / SettingsView both cap their scroll
        // areas at ~5 cards' worth so the popover never grows past a
        // sensible max. Bottom whitespace is constant: it equals the
        // rows VStack's bottom padding (12pt on home, 16pt in settings),
        // independent of how many cities are shown.
        .frame(width: 580)
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

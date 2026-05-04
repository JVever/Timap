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
        // Width is fixed; height is intrinsic so NSHostingController can
        // report the correct preferredContentSize to NSPopover. ZStack is
        // top-aligned so any unexpected overflow clips at the bottom only,
        // never chopping the header.
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
        // Fixed popover size. Locking both width AND height here means the
        // NSPopover's preferredContentSize never changes when the route
        // swaps (main ↔ settings ↔ onboarding), so the popover doesn't
        // jump around or reposition relative to the menu-bar icon. Each
        // route fills/scrolls inside this fixed container.
        .frame(width: 580, height: 640)
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

import SwiftUI
import TimapCore

/// v11 list area: city cards (one per city group), each containing the city
/// header, hour strip, and avatar+name chips. Hidden cards sort to the
/// bottom of the list (see `CityGroup.group`) and render at half opacity
/// with no green tint, so the visual fall-off itself signals their state.
///
/// Sizing: the ScrollView is intrinsic-height (capped) instead of
/// fill-available. That way the popover wraps the rows tightly and the
/// bottom whitespace below the last card stays constant — the VStack's
/// 12pt bottom padding — regardless of how many cities are shown. The
/// `maxHeight` cap kicks in only when the list grows past ~5 cards, at
/// which point the ScrollView starts scrolling internally.
struct TeamRowsView: View {
    @EnvironmentObject var state: AppState

    private static let cardGap: CGFloat = 8
    /// Height ceiling for the rows scroll area. Beyond this, content
    /// scrolls inside. Sized to fit ~5 chipped cards comfortably.
    private static let maxRowsHeight: CGFloat = 560

    var body: some View {
        let groups = state.citiesGrouped

        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: Self.cardGap) {
                ForEach(groups) { g in
                    CityCardView(group: g)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 12)
            .padding(.horizontal, 18)
        }
        .frame(maxHeight: Self.maxRowsHeight)
    }
}

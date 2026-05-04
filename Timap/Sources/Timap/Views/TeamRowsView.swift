import SwiftUI
import TimapCore

/// v11 list area: city cards (one per city group), each containing the city
/// header, hour strip, and avatar+name chips. ScrollView appears only when
/// the list is taller than the screen-aware cap. Hidden cards sort to the
/// bottom of the list (see `CityGroup.group`) and render at half opacity
/// with no green tint, so the visual fall-off itself signals their state.
struct TeamRowsView: View {
    @EnvironmentObject var state: AppState

    private static let cardGap: CGFloat = 8

    var body: some View {
        let groups = state.citiesGrouped

        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: Self.cardGap) {
                ForEach(groups) { g in
                    CityCardView(group: g)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 12)
            .padding(.horizontal, 18)
        }
        .frame(maxHeight: .infinity)
        .background(Color.black.opacity(0.18))
        .overlay(Divider(), alignment: .top)
    }
}

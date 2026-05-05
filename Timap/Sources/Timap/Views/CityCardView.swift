import SwiftUI
import TimapCore

private let bdAccent = Color(hex: "#ff8a5b")
private let v11Green = Color(hex: "#5fcf8a")
private let v11Amber = Color(hex: "#e8b86b")

/// v11 city card — represents one city with its members.
///
/// Layout (top → bottom):
///   • Header row (grid: city info LEFT, big local time RIGHT). The city
///     name itself is the hide toggle: tap to send the card to the bottom
///     of the list and exclude it from the meeting score.
///   • 24h work strip with the accent "now" line
///   • Avatar+name chips for non-host members (informational only)
///
/// Visual emphasis is on the *city*, not the member: city name & big time
/// shift to green when working, neutral white otherwise. Hidden cards drop
/// the green entirely (color would compete with active rows for attention)
/// and render at half opacity at the bottom of the list — tapping the city
/// name restores them.
struct CityCardView: View {
    let group: CityGroup
    @EnvironmentObject var state: AppState

    var body: some View {
        let localH = TimeMath.hourInTz(
            hostHour: state.hostHour,
            hostOffset: state.hostOffsetHours,
            targetOffset: group.offsetHours(at: state.hostInstant)
        )
        let inWork = TimeMath.isInWorkHours(
            localHour: localH, workStart: group.workStart, workEnd: group.workEnd
        )
        let hidden = group.isHidden
        // Hidden cards never adopt the green "active" tint — they sit
        // muted at the bottom and shouldn't draw the eye away from the
        // visible cities that actually drive scoring.
        let cityColor: Color = (inWork && !hidden) ? v11Green : Color.white.opacity(0.95)
        let delta = TimeMath.dayDelta(
            hostHour: state.hostHour,
            hostOffset: state.hostOffsetHours,
            targetOffset: group.offsetHours(at: state.hostInstant)
        )

        let chipMembers = group.members

        VStack(alignment: .leading, spacing: 8) {
            headerRow(cityColor: cityColor, localH: localH, delta: delta, hidden: hidden)
            hourStrip(hidden: hidden)
            if !chipMembers.isEmpty {
                memberChips(chipMembers)
            }
        }
        .padding(.top, 11)
        .padding(.bottom, 12)
        .padding(.horizontal, 14)
        .background(cardBackground(inWork: inWork && !hidden))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    inWork && !hidden ? v11Green.opacity(0.22) : Color.white.opacity(0.06),
                    lineWidth: 0.5
                )
        )
        .overlay(
            // 2pt left accent — sits on top of the 0.5pt border. Dim
            // when hidden so the strip doesn't dominate the row.
            HStack(spacing: 0) {
                Rectangle()
                    .fill(hidden ? Color.white.opacity(0.18) : cityColor)
                    .frame(width: 2)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(hidden ? 0.55 : 1)
        .animation(.easeInOut(duration: 0.2), value: cityColor)
        .animation(.easeInOut(duration: 0.2), value: hidden)
    }

    private func cardBackground(inWork: Bool) -> some View {
        Group {
            if inWork {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: v11Green.opacity(0.10), location: 0),
                        .init(color: v11Green.opacity(0.04), location: 1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Color.white.opacity(0.025)
            }
        }
    }

    // MARK: - Header row

    private func headerRow(cityColor: Color, localH: Double, delta: Int, hidden: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                cityNameButton(cityColor: cityColor, hidden: hidden)
                if group.isHome {
                    homeTag
                }
                Text(offsetDeltaText)
                    .font(.system(size: 11, weight: .regular).monospacedDigit())
                    .foregroundColor(.white.opacity(0.35))
            }
            Spacer(minLength: 8)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(TimapFormat.hour(localH, ampm: false, lang: state.language))
                    .font(.system(size: 24, weight: .medium).monospacedDigit())
                    .tracking(-0.5)
                    .foregroundColor(cityColor)
                if delta != 0 {
                    Text(L10n.relDay(delta, state.language))
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .foregroundColor(bdAccent)
                }
            }
        }
    }

    /// City name acts as the hide toggle. Home is non-tappable (you can't
    /// hide your own city — the rest of the UI uses it as the reference
    /// point for offset deltas).
    private func cityNameButton(cityColor: Color, hidden: Bool) -> some View {
        let label = Text(group.displayCity(state.language))
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(cityColor)
            .lineLimit(1)

        return Group {
            if group.isHome {
                label
            } else {
                Button {
                    state.toggleCityHidden(group.city)
                } label: {
                    label
                }
                .buttonStyle(.plain)
                .help(state.tr(hidden ? .clickToIncludeCityTooltip : .clickToHideCityTooltip))
            }
        }
    }

    private var homeTag: some View {
        Text(state.tr(.home))
            .font(.system(size: 9, weight: .bold))
            .tracking(0.4)
            .foregroundColor(bdAccent)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(bdAccent.opacity(0.12))
            )
    }

    private var offsetDeltaText: String {
        let d = group.offsetHours(at: state.hostInstant) - state.hostOffsetHours
        if abs(d) < 0.01 { return "" }
        let intD = Int(d.rounded())
        if Double(intD) == d {
            return d > 0 ? "+\(intD)h" : "\(intD)h"
        }
        let str = String(format: "%g", d)
        return d > 0 ? "+\(str)h" : "\(str)h"
    }

    // MARK: - Hour strip

    private func hourStrip(hidden: Bool) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                // 24 hourly cells matching the settings-page strip. Each
                // cell is split internally into two 30-min halves: a city
                // whose work starts at 9:30 fills the right half of the
                // 9-10 cell and the full 10-11 cell. Visual density stays
                // the same as the rest of the app, but the half-hour snap
                // is honored.
                HStack(spacing: 1.5) {
                    ForEach(0..<24, id: \.self) { i in
                        let firstHalf = isWorkAt(hostHour: Double(i))
                        let secondHalf = isWorkAt(hostHour: Double(i) + 0.5)
                        HalfHourCell(
                            firstHalf: firstHalf && !hidden,
                            secondHalf: secondHalf && !hidden
                        )
                    }
                }
                .frame(height: 5)

                Rectangle()
                    .fill(bdAccent)
                    .frame(width: 1.5, height: 11)
                    .shadow(color: bdAccent, radius: 2)
                    .offset(x: state.hostHour / 24 * w - 0.75, y: -3)
            }
            // Restore the strip-as-scrubber affordance from the pre-v11
            // rows: tap or drag anywhere on the strip to set hostHour, at
            // the same 15-min granularity as the main slider.
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let frac = max(0, min(1, g.location.x / w))
                        let snapped = (frac * 48).rounded() / 2
                        state.setHostHour(min(24, snapped))
                    }
            )
        }
        .frame(height: 5)
    }

    private func isWorkAt(hostHour: Double) -> Bool {
        let lh = TimeMath.hourInTz(
            hostHour: hostHour,
            hostOffset: state.hostOffsetHours,
            targetOffset: group.offsetHours(at: state.hostInstant)
        )
        return TimeMath.isInWorkHours(
            localHour: lh, workStart: group.workStart, workEnd: group.workEnd
        )
    }

    // MARK: - Member chips

    private func memberChips(_ members: [Teammate]) -> some View {
        // Wrap to multi-line so cities with 4+ members or long names don't
        // overflow horizontally and clip names off the card. Reuses the
        // FlowLayout primitive defined in SettingsMembersFlow.
        WrappingHStack(spacing: 6, lineSpacing: 6) {
            ForEach(members) { p in
                MemberChipView(person: p)
            }
        }
    }
}

/// One hour cell in the home page's city strip. Internally divided into
/// two 30-min halves so half-hour work boundaries (e.g. 9:30 → 23:00)
/// render correctly without inflating the cell count.
private struct HalfHourCell: View {
    let firstHalf: Bool
    let secondHalf: Bool

    private static let workColor = Color(red: 95/255, green: 207/255, blue: 138/255).opacity(0.55)
    private static let bgColor = Color.white.opacity(0.06)

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1).fill(Self.bgColor)
            GeometryReader { geo in
                if firstHalf {
                    Rectangle().fill(Self.workColor)
                        .frame(width: geo.size.width * 0.5)
                }
                if secondHalf {
                    Rectangle().fill(Self.workColor)
                        .frame(width: geo.size.width * 0.5)
                        .offset(x: geo.size.width * 0.5)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 1))
    }
}

/// Avatar+name pill — purely informational. Hide/include is now a
/// city-level operation, so chips don't react to taps.
private struct MemberChipView: View {
    let person: Teammate

    var body: some View {
        HStack(spacing: 6) {
            MemberAvatar(person: person)
            Text(person.name)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
                .lineLimit(1)
        }
        .padding(.leading, 3)
        .padding(.trailing, 9)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 999)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 999)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
    }
}

private struct MemberAvatar: View {
    let person: Teammate

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: person.colorHex))
            Text(person.initials)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(width: 20, height: 20)
    }
}

import SwiftUI
import AppKit
import TimapCore

// Palette + accent constants used across the v4 settings UI. Hex strings
// match the JSX prototype 1:1 so the live app reads the same as the design.
private let bdAccent  = Color(hex: "#ff8a5b")
private let bdGreen   = Color(hex: "#5fcf8a")
private let dangerRed = Color(hex: "#e85a5a")

/// Settings page — v4 redesign. Layout pivots on the city as a first-class
/// object: each city renders a card with its own work-hours editor and
/// member chips. Adding/editing/removing teammates and cities all happens
/// inline (no separate editor route). See `prototype/Timap Settings 重设计
/// v4.html` for the visual source of truth.
struct SettingsView: View {
    @EnvironmentObject var state: AppState
    var onClose: () -> Void

    @State private var addingCity = false
    @State private var justPromoted: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(state.citiesGrouped) { group in
                        CityCardSettingsView(
                            group: group,
                            justPromoted: justPromoted == group.city,
                            onSetHome: { setHome(group.city) },
                            onDeleteCity: { state.deleteCity(group.city) }
                        )
                    }
                    if addingCity {
                        CityAddForm(
                            existing: Set(state.citiesGrouped.map(\.city)),
                            onSave: { c in
                                state.addEmptyCity(c)
                                addingCity = false
                            },
                            onCancel: { addingCity = false }
                        )
                    } else {
                        addCityButton
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }
            // ScrollView fills the available vertical space inside the
            // popover. ContentView's outer .frame(height: 640) keeps the
            // popover the same size whether we're showing main, settings,
            // or onboarding — so opening settings doesn't shift the
            // popover's anchor position.
            .frame(maxHeight: .infinity)
            footer
        }
        .background(Color(hex: "#0d1420"))
    }

    private func setHome(_ city: String) {
        state.setHomeCity(city)
        justPromoted = city
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if justPromoted == city { justPromoted = nil }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Text(state.tr(.settings))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .tracking(-0.2)
            Spacer()
            LanguageSegmented(value: $state.language)
            Button(state.tr(.done), action: onClose)
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.white.opacity(0.14), lineWidth: 0.5)
                        )
                )
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.025), .clear],
                startPoint: .top, endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("Timap")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.3))
            Spacer()
            Button(state.tr(.quitApp)) { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
                .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(Color.black.opacity(0.18))
        .overlay(
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5),
            alignment: .top
        )
    }

    // MARK: - Add city CTA

    private var addCityButton: some View {
        Button(action: { addingCity = true }) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .heavy))
                Text(state.tr(.addCity))
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(bdAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(bdAccent.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(bdAccent.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Language segmented

private struct LanguageSegmented: View {
    @Binding var value: AppLanguage

    var body: some View {
        HStack(spacing: 0) {
            seg(.zh, label: "中")
            Rectangle().fill(Color.white.opacity(0.12)).frame(width: 0.5)
            seg(.en, label: "EN")
        }
        .frame(height: 22)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func seg(_ lang: AppLanguage, label: String) -> some View {
        let active = value == lang
        Button(action: { value = lang }) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(active ? bdAccent : Color.white.opacity(0.7))
                .padding(.horizontal, 12)
                .frame(maxHeight: .infinity)
                .background(active ? bdAccent.opacity(0.16) : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - City card

private struct CityCardSettingsView: View {
    let group: CityGroup
    let justPromoted: Bool
    let onSetHome: () -> Void
    let onDeleteCity: () -> Void

    @EnvironmentObject var state: AppState
    @State private var hovered = false
    @State private var confirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            workHoursSection
                .padding(.top, 4)
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 0.5)
                .padding(.top, 12)
            membersRow
                .padding(.top, 12)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(
            ZStack {
                if group.isHome {
                    LinearGradient(
                        colors: [bdAccent.opacity(0.06), bdAccent.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    )
                } else {
                    Color.white.opacity(0.025)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    group.isHome ? bdAccent.opacity(0.22) : Color.white.opacity(0.06),
                    lineWidth: 0.5
                )
        )
        .overlay(
            HStack(spacing: 0) {
                Rectangle()
                    .fill(group.isHome ? bdAccent : Color.white.opacity(0.18))
                    .frame(width: 2)
                Spacer()
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(bdAccent, lineWidth: justPromoted ? 1.5 : 0)
                .opacity(justPromoted ? 1 : 0)
                .shadow(color: bdAccent.opacity(0.25), radius: justPromoted ? 12 : 0)
        )
        .animation(.easeInOut(duration: 0.4), value: justPromoted)
        .onHover { h in
            hovered = h
            if !h { confirmingDelete = false }
        }
    }

    // MARK: header

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text(group.displayCity(state.language))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
            if group.isHome {
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
            Text(utcLabel)
                .font(.system(size: 10.5).monospacedDigit())
                .foregroundColor(.white.opacity(0.4))
            Spacer()
            if confirmingDelete {
                deleteConfirm
            } else {
                hoverActions
            }
        }
        .frame(minHeight: 22)
    }

    private var utcLabel: String {
        let off = group.offsetHours
        let sign = off >= 0 ? "+" : ""
        if off == off.rounded() { return "UTC\(sign)\(Int(off))" }
        return String(format: "UTC%@%g", sign, off)
    }

    @ViewBuilder
    private var hoverActions: some View {
        let canDelete = !group.isHome
        HStack(spacing: 6) {
            if !group.isHome {
                Button(state.tr(.setAsHome), action: onSetHome)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(bdAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(bdAccent.opacity(0.14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(bdAccent.opacity(0.4), lineWidth: 0.5)
                            )
                    )
            }
            Button(action: { if canDelete { confirmingDelete = true } }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(canDelete ? Color.white.opacity(0.6) : Color.white.opacity(0.2))
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canDelete)
            .help(canDelete
                  ? state.tr(.deleteCity)
                  : state.tr(.cantDeleteHome))
        }
        .opacity(hovered ? 1 : 0)
        .offset(x: hovered ? 0 : 4)
        .animation(.easeOut(duration: 0.14), value: hovered)
    }

    private var deleteConfirm: some View {
        let memberCount = group.members.count
        let label = L10n.deleteCityPrompt(
            group.displayCity(state.language),
            memberCount: memberCount,
            state.language
        )
        return HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "#ff9b9b"))
                .fixedSize(horizontal: true, vertical: false)
            Button(state.tr(.confirm)) {
                onDeleteCity()
                confirmingDelete = false
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 7).padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 3).fill(dangerRed.opacity(0.35)))
            .fixedSize()
            Button(state.tr(.cancel)) { confirmingDelete = false }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.55))
                .fixedSize()
        }
        .padding(.horizontal, 9).padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(dangerRed.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(dangerRed.opacity(0.4), lineWidth: 0.5)
                )
        )
    }

    // MARK: work hours

    private var workHoursSection: some View {
        WorkHoursStripEditor(
            workStart: group.workStart,
            workEnd: group.workEnd,
            label: state.tr(.workHoursLabel),
            onChange: { ws, we in
                state.setCityWorkHours(group.city, start: ws, end: we)
            }
        )
    }

    // MARK: members

    private var membersRow: some View {
        MembersFlowView(
            cityName: group.city,
            members: group.members,
            workStart: group.workStart,
            workEnd: group.workEnd,
            onUpsert: { p in
                var pp = p
                // Always pin the member's geo + work hours to the city's
                // current values. Otherwise a freshly-added teammate's
                // default 9-23 hours could win over the city's customized
                // hours when CityCanonicalizer.syncWorkHours picks the
                // alphabetically-first member as anchor.
                pp.city = group.city
                pp.cityZh = group.cityZh
                pp.country = group.country
                pp.flag = group.flag
                pp.lat = group.lat
                pp.lng = group.lng
                pp.tzIdentifier = group.tzIdentifier
                pp.workStart = group.workStart
                pp.workEnd = group.workEnd
                state.upsert(pp)
            },
            onRemove: { id in
                state.remove(id)
            }
        )
    }
}

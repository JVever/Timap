import SwiftUI
import TimapCore

private let bdAccent = Color(hex: "#ff8a5b")

/// Inline form rendered in the settings page when the user clicks "+ 添加新城市".
/// Two modes:
///   - search (default): typeahead against `CityCatalog`. Up/Down/Enter/Escape
///     all wired. If no result matches, surfaces a "manually add" affordance
///     pre-seeded with the typed query.
///   - manual: required CN/EN names + UTC offset + lat/lng for placement.
///     The country falls through to a globe emoji 🌐.
struct CityAddForm: View {
    let existing: Set<String>
    let onSave: (City) -> Void
    let onCancel: () -> Void

    @EnvironmentObject var state: AppState
    @State private var mode: Mode = .search
    @State private var query = ""
    @State private var hoverIdx = 0
    @FocusState private var searchFocused: Bool

    enum Mode: Equatable { case search, manual(seed: String) }

    private var lowerExisting: Set<String> {
        Set(existing.map { $0.lowercased() })
    }

    private var matches: [City] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return [] }
        let lowerExist = lowerExisting
        return CityCatalog.search(trimmed, limit: 6)
            .filter { !lowerExist.contains($0.name.lowercased()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch mode {
            case .search:
                searchView
            case .manual(let seed):
                ManualCityForm(
                    seed: seed,
                    existingLower: lowerExisting,
                    onSave: { c in onSave(c) },
                    onBack: { mode = .search; searchFocused = true },
                    onCancel: onCancel
                )
            }
        }
    }

    // MARK: - Search

    private var searchView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                TextField(state.tr(.searchCityPlaceholderV4), text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.white)
                    .focused($searchFocused)
                    .onAppear { DispatchQueue.main.async { searchFocused = true } }
                    .onChange(of: query) { _ in hoverIdx = 0 }
                    .onSubmit {
                        if !matches.isEmpty {
                            pick(matches[min(hoverIdx, matches.count - 1)])
                        }
                    }
                Button(state.tr(.cancel), action: onCancel)
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
                    .keyboardShortcut(.cancelAction)
            }
            .onMoveCommand { direction in
                guard !matches.isEmpty else { return }
                switch direction {
                case .up: hoverIdx = max(0, hoverIdx - 1)
                case .down: hoverIdx = min(matches.count - 1, hoverIdx + 1)
                default: break
                }
            }

            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                emptyHint
            } else if matches.isEmpty {
                noMatchHint
            } else {
                matchList
            }
        }
        .padding(10)
        .background(formBackground)
    }

    private var emptyHint: some View {
        HStack(spacing: 4) {
            Text(state.tr(.searchHint))
                .font(.system(size: 10.5))
                .foregroundColor(.white.opacity(0.4))
            Button(action: { mode = .manual(seed: "") }) {
                Text(state.tr(.manualAddSelf))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(bdAccent)
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    private var matchList: some View {
        VStack(spacing: 1) {
            ForEach(Array(matches.enumerated()), id: \.element.id) { idx, c in
                Button(action: { pick(c) }) {
                    HStack(spacing: 10) {
                        Text(c.flag).font(.system(size: 13))
                        Text(c.displayName(state.language))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Text(c.country)
                            .font(.system(size: 10.5))
                            .foregroundColor(.white.opacity(0.45))
                        Spacer()
                        Text(utcLabel(c))
                            .font(.system(size: 10.5).monospacedDigit())
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(idx == hoverIdx ? bdAccent.opacity(0.16) : .clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { if $0 { hoverIdx = idx } }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.black.opacity(0.2))
        )
    }

    private var noMatchHint: some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        return VStack(alignment: .leading, spacing: 4) {
            Text(L10n.noMatchFor(q, state.language))
                .font(.system(size: 11.5))
                .foregroundColor(.white.opacity(0.65))
            Text(state.tr(.noMatchTryEnglish))
                .font(.system(size: 10.5))
                .foregroundColor(.white.opacity(0.45))
            Button(action: { mode = .manual(seed: q) }) {
                Text(L10n.manualAddWithQuery(q, state.language))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(bdAccent)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(bdAccent.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(bdAccent.opacity(0.5), lineWidth: 0.5)
                            )
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.black.opacity(0.2))
        )
    }

    private var formBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(bdAccent.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(bdAccent.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
    }

    private func pick(_ c: City) {
        onSave(c)
    }

    private func utcLabel(_ c: City) -> String {
        let off = Double(TimeZone(identifier: c.tz)?.secondsFromGMT() ?? 0) / 3600.0
        let sign = off >= 0 ? "+" : ""
        if off == off.rounded() { return "UTC\(sign)\(Int(off))" }
        return String(format: "UTC%@%g", sign, off)
    }
}

// MARK: - Manual entry

private struct ManualCityForm: View {
    let seed: String
    let existingLower: Set<String>
    let onSave: (City) -> Void
    let onBack: () -> Void
    let onCancel: () -> Void

    @EnvironmentObject var state: AppState
    @State private var cn: String
    @State private var en: String
    @State private var offset: String = "8"
    @State private var lat: String = ""
    @State private var lng: String = ""

    init(seed: String, existingLower: Set<String>,
         onSave: @escaping (City) -> Void, onBack: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.seed = seed
        self.existingLower = existingLower
        self.onSave = onSave
        self.onBack = onBack
        self.onCancel = onCancel
        let isCn = Initials.hasCJK(seed)
        _cn = State(initialValue: isCn ? seed : "")
        _en = State(initialValue: isCn ? "" : seed)
    }

    /// Manual cities only support integer UTC offsets. Reason: we synthesize
    /// a fixed-offset `Etc/GMT±N` identifier which doesn't accept fractional
    /// hours. Cities at half/quarter offsets (Mumbai +5.5, Tehran +3.5,
    /// Kathmandu +5.75, Adelaide +9.5, etc.) are already in cities.json with
    /// proper IANA tzs — users should pick those from the catalog.
    private var offsetValue: Int? {
        let trimmed = offset.trimmingCharacters(in: .whitespaces)
        guard let n = Int(trimmed), n >= -12, n <= 14 else { return nil }
        return n
    }
    private var latValue: Double? {
        let n = Double(lat.trimmingCharacters(in: .whitespaces))
        guard let n = n, n >= -90, n <= 90 else { return nil }
        return n
    }
    private var lngValue: Double? {
        let n = Double(lng.trimmingCharacters(in: .whitespaces))
        guard let n = n, n >= -180, n <= 180 else { return nil }
        return n
    }
    private var enConflict: Bool {
        let trimmed = en.trimmingCharacters(in: .whitespaces).lowercased()
        return !trimmed.isEmpty && existingLower.contains(trimmed)
    }
    private var cnConflict: Bool {
        let trimmed = cn.trimmingCharacters(in: .whitespaces).lowercased()
        return !trimmed.isEmpty && existingLower.contains(trimmed)
    }
    private var canSave: Bool {
        !cn.trimmingCharacters(in: .whitespaces).isEmpty
            && !en.trimmingCharacters(in: .whitespaces).isEmpty
            && offsetValue != nil && latValue != nil && lngValue != nil
            && !enConflict && !cnConflict
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(state.tr(.manualCityTitle))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Text(state.tr(.manualCityHint))
                    .font(.system(size: 10.5))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Button(state.tr(.backToSearch), action: onBack)
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(bdAccent)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                ManualField(label: state.tr(.fieldCnName), required: true) {
                    ManualInput(value: $cn, placeholder: state.tr(.manualCnExample),
                                invalid: cnConflict)
                }
                ManualField(label: state.tr(.fieldEnName), required: true) {
                    ManualInput(value: $en, placeholder: state.tr(.manualEnExample),
                                invalid: enConflict)
                }
                ManualField(label: state.tr(.fieldUtcOffset), required: true) {
                    ManualInput(value: $offset, placeholder: state.tr(.manualUtcExample),
                                invalid: !offset.isEmpty && offsetValue == nil)
                }
                ManualField(label: state.tr(.fieldLat), required: true) {
                    ManualInput(value: $lat, placeholder: state.tr(.manualLatExample),
                                invalid: !lat.isEmpty && latValue == nil, mono: true)
                }
                ManualField(label: state.tr(.fieldLng), required: true) {
                    ManualInput(value: $lng, placeholder: state.tr(.manualLngExample),
                                invalid: !lng.isEmpty && lngValue == nil, mono: true)
                }
            }

            if cnConflict || enConflict {
                Text(state.tr(.duplicateCityWarning))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(Color(hex: "#ff9b9b"))
            }

            Text(state.tr(.coordsHint))
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.35))

            HStack {
                Spacer()
                Button(state.tr(.cancel), action: onCancel)
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                Button(state.tr(.add), action: commit)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(canSave ? bdAccent : .white.opacity(0.3))
                    .padding(.horizontal, 14).padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(canSave ? bdAccent.opacity(0.18) : Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(canSave ? bdAccent.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 0.5)
                            )
                    )
                    .disabled(!canSave)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(bdAccent.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(bdAccent.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [4]))
                )
        )
    }

    private func commit() {
        guard canSave, let off = offsetValue, let la = latValue, let ln = lngValue else { return }
        let cnTrim = cn.trimmingCharacters(in: .whitespaces)
        let enTrim = en.trimmingCharacters(in: .whitespaces)
        let tz = Self.fixedOffsetIdentifier(off)
        let city = City(
            name: enTrim, nameZh: cnTrim,
            country: "", flag: "🌐",
            lat: la, lng: ln, tz: tz
        )
        onSave(city)
    }

    /// IANA POSIX-style fixed offset id. Etc/GMT zones invert sign
    /// (Etc/GMT-8 means UTC+8). Integer-only because offsetValue rejects
    /// fractional input.
    private static func fixedOffsetIdentifier(_ hours: Int) -> String {
        let inv = -hours
        let sign = inv >= 0 ? "+" : "-"
        return "Etc/GMT\(sign)\(abs(inv))"
    }
}

private struct ManualField<Content: View>: View {
    let label: String
    let required: Bool
    let content: () -> Content

    init(label: String, required: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.required = required
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.3)
                    .foregroundColor(.white.opacity(0.5))
                if required {
                    Text("*").foregroundColor(bdAccent).font(.system(size: 9.5, weight: .bold))
                }
            }
            content()
        }
    }
}

private struct ManualInput: View {
    @Binding var value: String
    let placeholder: String
    var invalid: Bool = false
    var mono: Bool = false

    var body: some View {
        TextField(placeholder, text: $value)
            .textFieldStyle(.plain)
            .font(mono
                  ? .system(size: 11.5, weight: .medium).monospacedDigit()
                  : .system(size: 11.5, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.black.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(invalid ? Color(hex: "#e85a5a").opacity(0.6) : Color.white.opacity(0.12), lineWidth: 0.5)
                    )
            )
    }
}

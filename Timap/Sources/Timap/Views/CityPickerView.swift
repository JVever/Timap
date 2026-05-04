import SwiftUI
import TimapCore

private let bdAccent = Color(hex: "#ff8a5b")

/// Reusable city autocomplete. Shows a search field; below it a list of
/// matching cities. Tapping a row calls `onSelect`.
struct CityPickerView: View {
    @Binding var query: String
    var onSelect: (City) -> Void
    var placeholder: String? = nil

    @EnvironmentObject var state: AppState

    private func subtitle(for city: City) -> String {
        // In Chinese mode show "<English name> · <tz>" so the user still
        // sees the canonical name. In English mode show "<country> · <tz>"
        // since name is already canonical.
        switch state.language {
        case .zh:
            return "\(city.name) · \(city.tz)"
        case .en:
            return "\(city.country) · \(city.tz)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.45))
                TextField(placeholder ?? state.tr(.searchCity), text: $query)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .font(.system(size: 13))
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
            )

            let results = CityCatalog.search(query, limit: 8)
            if results.isEmpty {
                Text(state.tr(.noMatchingCity))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 0) {
                    ForEach(results) { city in
                        Button {
                            onSelect(city)
                        } label: {
                            HStack(spacing: 8) {
                                Text(city.flag).font(.system(size: 14))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(city.displayName(state.language))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                    // Always show the IANA tz + alt-language name
                                    // as a small subtitle so the row stays
                                    // unambiguous regardless of language.
                                    Text(subtitle(for: city))
                                        .font(.system(size: 9.5).monospacedDigit())
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(
                            Color.white.opacity(0.0001) // make hit area solid
                        )
                        Divider()
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                )
            }
        }
    }
}

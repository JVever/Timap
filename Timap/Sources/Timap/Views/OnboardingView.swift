import SwiftUI
import TimapCore

private let bdAccent = Color(hex: "#ff8a5b")

struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @State private var query: String = ""
    @State private var picked: City?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(state.tr(.welcome))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text(state.tr(.whereBased))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                Text(state.tr(.locationHint))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.top, 1)
            }

            CityPickerView(
                query: $query,
                onSelect: { city in
                    picked = city
                    query = city.displayName(state.language)
                },
                placeholder: state.tr(.locationSearchPlaceholder)
            )

            if let p = picked {
                HStack(spacing: 10) {
                    Text(p.flag).font(.system(size: 18))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.displayName(state.language))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text(p.tz)
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundColor(.white.opacity(0.55))
                    }
                    Spacer()
                    Button(state.tr(.getStarted)) {
                        state.completeOnboarding(home: p)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(bdAccent)
                    )
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(bdAccent.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(bdAccent.opacity(0.4), lineWidth: 0.5)
                        )
                )
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

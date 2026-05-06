import SwiftUI
import TimapCore

// Onboarding redesign (Claude Design handoff y-vebNZtVtp2mRMmUofLkw):
// Two steps — welcome page introduces what Timap is, then the city picker
// commits the user's home time zone. Brand green (#5fcf8a) takes over from
// the orange accent inside this flow because the green intersection bar in
// the logo is the visual answer to the value prop ("find the overlap").

private let onbGreen = Color(hex: "#5fcf8a")
private let onbInk   = Color(hex: "#0d1420")
private let onbBgTop = Color(hex: "#1a2c44")
private let onbBgBot = Color(hex: "#0d141f")

private let onbHotCityNames = ["Beijing", "Shanghai", "Tokyo", "Singapore", "London"]

struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @State private var step: Step = .welcome

    enum Step { case welcome, cityPick }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [onbBgTop, onbBgBot],
                startPoint: UnitPoint(x: 0, y: 0),
                endPoint: UnitPoint(x: 1, y: 1)
            )

            Group {
                switch step {
                case .welcome:
                    WelcomeStepView(onNext: {
                        withAnimation(.easeInOut(duration: 0.3)) { step = .cityPick }
                    })
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                case .cityPick:
                    CityPickStepView(
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.3)) { step = .welcome }
                        },
                        onDone: { city in state.completeOnboarding(home: city) }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            LangSwitchView()
                .padding(.top, 14)
                .padding(.trailing, 14)
        }
        .frame(height: 640)
        .clipped()
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStepView: View {
    @EnvironmentObject var state: AppState
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Body — vertically centered logo + headline + bullets
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)

                AnimatedLogo(size: 120)
                    .padding(.bottom, 28)

                Text(state.tr(.welcome))
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.28)
                    .foregroundColor(.white)

                Text(state.tr(.welcomeSub))
                    .font(.system(size: 14))
                    .lineSpacing(14 * 0.55)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 10)
                    .frame(maxWidth: 420, alignment: .leading)

                VStack(alignment: .leading, spacing: 10) {
                    bullet(state.tr(.welcomeBullet1))
                    bullet(state.tr(.welcomeBullet2))
                    bullet(state.tr(.welcomeBullet3))
                }
                .padding(.top, 24)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            // Footer
            HStack {
                StepDots(activeIndex: 0, total: 2)
                Spacer()
                PrimaryButton(state.tr(.onbNext), enabled: true, showArrow: true, action: onNext)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 0.5),
                alignment: .top
            )
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(onbGreen)
                .frame(width: 4, height: 4)
                .padding(.top, 8)
            Text(text)
                .font(.system(size: 13))
                .lineSpacing(13 * 0.5)
                .foregroundColor(.white.opacity(0.78))
        }
    }
}

// MARK: - Step 2: City pick

private struct CityPickStepView: View {
    @EnvironmentObject var state: AppState
    let onBack: () -> Void
    let onDone: (City) -> Void

    @State private var query: String = ""
    @State private var picked: City?
    @FocusState private var searchFocused: Bool

    private var hotCities: [City] {
        onbHotCityNames.compactMap { name in CityCatalog.all.first { $0.name == name } }
    }
    private var results: [City] { CityCatalog.search(query, limit: 8) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                )
                        )
                }
                .buttonStyle(.plain)
                .help(state.tr(.onbBack))
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(state.tr(.whereBased))
                        .font(.system(size: 19, weight: .bold))
                        .tracking(-0.19)
                        .foregroundColor(.white)
                    Text(state.tr(.locationHint))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.55))
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 24)
            .padding(.horizontal, 28)
            .padding(.bottom, 12)

            // Body
            VStack(alignment: .leading, spacing: 16) {
                searchField

                if query.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel(state.tr(.onbHotLabel))
                        chipRow
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    if !query.isEmpty {
                        sectionLabel(state.tr(.onbResultsLabel))
                    }
                    resultsList
                }
                .frame(maxHeight: .infinity)
            }
            .padding(.top, 8)
            .padding(.horizontal, 28)

            // Footer
            VStack(alignment: .leading, spacing: 12) {
                if let p = picked {
                    SelectedPreview(city: p)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                HStack {
                    StepDots(activeIndex: 1, total: 2)
                    Spacer()
                    PrimaryButton(
                        picked != nil ? state.tr(.getStarted) : state.tr(.onbSelectToContinue),
                        enabled: picked != nil,
                        showArrow: picked != nil,
                        action: { if let p = picked { onDone(p) } }
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 0.5),
                alignment: .top
            )
            .animation(.easeInOut(duration: 0.2), value: picked != nil)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundColor(.white.opacity(0.4))
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.45))
            TextField(state.tr(.locationSearchPlaceholder), text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .focused($searchFocused)
                .onAppear { DispatchQueue.main.async { searchFocused = true } }
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
        )
    }

    private var chipRow: some View {
        HStack(spacing: 6) {
            ForEach(hotCities) { city in
                let active = picked?.id == city.id
                Button { picked = city } label: {
                    HStack(spacing: 6) {
                        CountryCodeBadge(code: city.country, size: .sm)
                        Text(city.displayName(state.language))
                            .font(.system(size: 12))
                            .foregroundColor(active ? onbGreen : .white.opacity(0.85))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(active ? onbGreen.opacity(0.14) : Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(active ? onbGreen.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 0.5)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    private var resultsList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                if results.isEmpty {
                    Text(state.tr(.noMatchingCity))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(Array(results.enumerated()), id: \.element.id) { (i, city) in
                        let active = picked?.id == city.id
                        Button { picked = city } label: {
                            HStack(spacing: 0) {
                                CountryCodeBadge(code: city.country, size: .md)
                                    .padding(.trailing, 12)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(city.displayName(state.language))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text(metaLine(for: city))
                                        .font(.system(size: 10.5).monospaced())
                                        .tracking(0.2)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                Spacer()
                                if active {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(onbGreen)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(active ? onbGreen.opacity(0.10) : Color.clear)
                            .overlay(
                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: i == 0 ? 0 : 0.5),
                                alignment: .top
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        )
    }

    private func metaLine(for city: City) -> String {
        switch state.language {
        case .zh: return "\(city.country) · \(city.name)"
        case .en: return "\(city.country) · \(city.tz)"
        }
    }
}

// "Now H:MM" preview card under the picker — the green tint mirrors the
// CTA so the user sees a single consistent confirmation cue. The time
// auto-refreshes every 60s via TimelineView.periodic.
private struct SelectedPreview: View {
    @EnvironmentObject var state: AppState
    let city: City

    var body: some View {
        HStack(spacing: 12) {
            CountryCodeBadge(code: city.country, size: .lg)
            VStack(alignment: .leading, spacing: 2) {
                Text(city.displayName(state.language))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                NowInCity(tz: city.tz)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(onbGreen.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(onbGreen.opacity(0.3), lineWidth: 0.5)
                )
        )
    }
}

private struct NowInCity: View {
    @EnvironmentObject var state: AppState
    let tz: String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            HStack(spacing: 4) {
                Text(state.tr(.now))
                    .font(.system(size: 11, weight: .semibold).monospaced())
                    .foregroundColor(onbGreen)
                Text(formatted(ctx.date))
                    .font(.system(size: 11, weight: .semibold).monospaced())
                    .foregroundColor(onbGreen)
            }
        }
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: tz) ?? .current
        f.dateFormat = state.language == .en ? "h:mm a" : "H:mm"
        return f.string(from: date)
    }
}

// MARK: - Animated logo (welcome step entry)

// Three-bar brand mark; bars assemble in sequence over 1.4s on first
// appear: white middle slides in from the left, white bottom slides in
// from the right, green intersection bar drops in from above with a
// spring at the end so it punches a tiny visual landing.
private struct AnimatedLogo: View {
    let size: CGFloat

    @State private var fade1: Double = 0
    @State private var fade2: Double = 0
    @State private var fade3: Double = 0

    var body: some View {
        let s = size / 1024
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 220 * s)
                .fill(onbInk)
                .frame(width: size, height: size)

            // White mid bar
            RoundedRectangle(cornerRadius: 17.1 * s)
                .fill(Color.white)
                .frame(width: 561.6 * s, height: 114 * s)
                .position(x: (80 + 561.6 / 2) * s, y: (455 + 114 / 2) * s)
                .offset(x: -120 * s * (1 - fade1))
                .opacity(fade1)

            // White bottom bar
            RoundedRectangle(cornerRadius: 17.1 * s)
                .fill(Color.white)
                .frame(width: 544.32 * s, height: 114 * s)
                .position(x: (399.68 + 544.32 / 2) * s, y: (659 + 114 / 2) * s)
                .offset(x: 120 * s * (1 - fade2))
                .opacity(fade2)

            // Green top bar (intersection — the visual punchline)
            RoundedRectangle(cornerRadius: 17.1 * s)
                .fill(onbGreen)
                .frame(width: 241.92 * s, height: 114 * s)
                .position(x: (399.68 + 241.92 / 2) * s, y: (251 + 114 / 2) * s)
                .offset(y: -180 * s * (1 - fade3))
                .opacity(fade3)
        }
        .frame(width: size, height: size)
        .onAppear { runAssembly() }
    }

    private func runAssembly() {
        withAnimation(.easeOut(duration: 0.4)) { fade1 = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeOut(duration: 0.4)) { fade2 = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) { fade3 = 1 }
        }
    }
}

// MARK: - Country-code badge

// Replaces emoji flags inside onboarding: more legible at small sizes,
// avoids the political/regional noise emoji flags carry on macOS, and
// the tinted variant doubles as a CTA confirmation marker.
private struct CountryCodeBadge: View {
    enum Size { case sm, md, lg }
    let code: String
    let size: Size

    var body: some View {
        Text(code.uppercased())
            .font(font)
            .tracking(tracking)
            .foregroundColor(textColor)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(bgColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(borderColor, lineWidth: 0.5)
                    )
            )
    }

    private var font: Font {
        switch size {
        case .sm: return .system(size: 9.5, weight: .semibold).monospaced()
        case .md: return .system(size: 10.5, weight: .semibold).monospaced()
        case .lg: return .system(size: 12, weight: .bold).monospaced()
        }
    }
    private var tracking: Double {
        switch size {
        case .sm, .md: return 0.4
        case .lg: return 0.6
        }
    }
    private var width: CGFloat {
        switch size {
        case .sm: return 22
        case .md: return 32
        case .lg: return 40
        }
    }
    private var height: CGFloat {
        switch size {
        case .sm: return 18
        case .md: return 32
        case .lg: return 40
        }
    }
    private var cornerRadius: CGFloat {
        switch size {
        case .sm: return 4
        case .md: return 6
        case .lg: return 8
        }
    }
    private var textColor: Color {
        size == .lg ? onbGreen : .white.opacity(0.78)
    }
    private var bgColor: Color {
        switch size {
        case .lg: return onbGreen.opacity(0.10)
        case .md: return Color.white.opacity(0.04)
        case .sm: return Color.white.opacity(0.06)
        }
    }
    private var borderColor: Color {
        size == .lg ? onbGreen.opacity(0.35) : Color.white.opacity(0.14)
    }
}

// MARK: - Step dots

private struct StepDots: View {
    let activeIndex: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                let active = i == activeIndex
                RoundedRectangle(cornerRadius: 3)
                    .fill(active ? onbGreen : Color.white.opacity(0.18))
                    .frame(width: active ? 18 : 6, height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: activeIndex)
    }
}

// MARK: - Primary button

private struct PrimaryButton: View {
    let label: String
    let enabled: Bool
    let showArrow: Bool
    let action: () -> Void

    init(_ label: String, enabled: Bool, showArrow: Bool = true, action: @escaping () -> Void) {
        self.label = label
        self.enabled = enabled
        self.showArrow = showArrow
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                if showArrow {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.leading, 8)
                }
            }
            .foregroundColor(enabled ? onbInk : .white.opacity(0.35))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(enabled ? onbGreen : Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .animation(.easeInOut(duration: 0.2), value: enabled)
    }
}

// MARK: - Language switch

private struct LangSwitchView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 0) {
            langBtn("中文", lang: .zh)
            langBtn("English", lang: .en)
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
    }

    private func langBtn(_ label: String, lang: AppLanguage) -> some View {
        let active = state.language == lang
        return Button { state.language = lang } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(active ? .white : .white.opacity(0.55))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(active ? Color.white.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

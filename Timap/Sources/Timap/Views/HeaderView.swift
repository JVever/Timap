import SwiftUI
import TimapCore

private let bdAccent = Color(hex: "#ff8a5b")
private let v11Green = Color(hex: "#5fcf8a")
private let v11Amber = Color(hex: "#e8b86b")

/// v11 header layout (single row, 12pt gap):
///   1. Big time as a tap target — double-tap jumps to the next best window.
///      Color encodes meeting readiness (replaces the old status pill).
///   2. Compact 28pt-tall two-line date block (weekday over date).
///   3. Right-edge segmented capsule combining "现在" + gear icon, sharing
///      one rounded shell with a 0.5pt internal divider.
struct HeaderView: View {
    @EnvironmentObject var state: AppState
    var onOpenSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            timeButton
            dateBlock
            Spacer(minLength: 8)
            segmentedActions
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    /// Slider position can sit at exactly 24 (= start of next day). For
    /// display, we collapse to mod-24 hour and shift the date forward by
    /// the carried day count, so the header matches what the city cards
    /// already show ("00:00 明天" instead of "上午 12:00 today").
    private var displayHour: Double {
        let h = state.hostHour
        let dayCount = floor(h / 24)
        return h - dayCount * 24
    }

    private var displayDate: Date {
        let dayCount = Int(floor(state.hostHour / 24))
        if dayCount == 0 { return state.hostDate }
        return Calendar.current.date(
            byAdding: .day, value: dayCount, to: state.hostDate
        ) ?? state.hostDate
    }

    private var timeColor: Color {
        let score = TimeMath.meetingScore(
            hostHour: state.hostHour,
            hostOffset: state.hostOffsetHours,
            team: state.scoringTeam,
            at: state.hostInstant
        )
        if score >= 0.95 { return v11Green }
        if score >= 0.65 { return v11Amber }
        return .white.opacity(0.95)
    }

    private var timeButton: some View {
        // Plain Text + tap gesture (no Button) — single click cycles to
        // the next recommended meeting window. Earlier we used double-tap
        // but the affordance was undiscoverable.
        Text(TimapFormat.hour(displayHour, lang: state.language))
            .font(.system(size: 30, weight: .medium).monospacedDigit())
            .tracking(-0.8)
            .foregroundColor(timeColor)
            .lineLimit(1)
            .fixedSize()
            .contentShape(Rectangle())
            .onTapGesture { state.jumpToBestWindow() }
            .help(state.tr(.jumpToBestSlotTooltip))
            .animation(.easeInOut(duration: 0.25), value: timeColor)
    }

    private var dateBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(weekdayText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
            Spacer(minLength: 0)
            Text(monthDayText)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundColor(.white.opacity(0.55))
        }
        .frame(height: 28)
    }

    private var weekdayText: String {
        let cal = currentCalendar()
        let idx = cal.component(.weekday, from: displayDate) - 1
        let zh = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let en = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return state.language == .zh ? zh[idx] : en[idx]
    }

    private var monthDayText: String {
        let cal = currentCalendar()
        let m = cal.component(.month, from: displayDate)
        let d = cal.component(.day, from: displayDate)
        let monthsEn = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return state.language == .zh ? "\(m)月\(d)日" : "\(monthsEn[m - 1]) \(d)"
    }

    private func currentCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = state.hostTimeZone
        return cal
    }

    private var segmentedActions: some View {
        HStack(spacing: 0) {
            nowButton
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 0.5)
            gearButton
        }
        .frame(height: 28)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var nowButton: some View {
        let isAtNow = state.isLive
        return Button {
            if !isAtNow { state.goLive() }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(isAtNow ? bdAccent : Color.white.opacity(0.85))
                    .frame(width: 6, height: 6)
                    .shadow(color: isAtNow ? bdAccent : .clear, radius: isAtNow ? 3 : 0)
                Text(state.tr(.now))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isAtNow ? .white.opacity(0.55) : .white.opacity(0.95))
            }
            .padding(.horizontal, 12)
            .frame(height: 28)
            // Without contentShape, only the rendered glyphs (the dot
            // and the text characters) are hit-testable — clicking the
            // padding region between them is dead. Force the entire
            // capsule half to take taps.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isAtNow)
        .help(state.tr(isAtNow ? .atNowTooltip : .goLiveTooltip))
        .animation(.easeInOut(duration: 0.2), value: isAtNow)
    }

    private var gearButton: some View {
        Button(action: onOpenSettings) {
            Image(systemName: "gearshape")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 32, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(state.tr(.settings))
    }
}

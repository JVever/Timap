import SwiftUI
import TimapCore

private let bdAccent = Color(hex: "#ff8a5b")
private let v11Green = Color(hex: "#5fcf8a")
private let v11Amber = Color(hex: "#e8b86b")
private let v11BgInner = Color(hex: "#0d1420")

/// v11 slider:
///   • 6pt-tall track with recommendation bands (green=great / amber=good).
///   • Active band (the one containing hostHour) renders a vertical gradient
///     and goes to opacity 1; inactive bands stay at standard 0.28 opacity.
///   • 18pt circular thumb whose fill matches the active band's color (or
///     white when no band is active), with an outer dark ring + glow shadow.
///   • Below the track, a 14pt label strip with anchored "0" / "24" plus
///     an hour label at each band endpoint, colored to match the band.
struct TimeSliderView: View {
    @EnvironmentObject var state: AppState

    private static let standardActive: Double = 1.0
    private static let standardBase: Double = 0.28

    var body: some View {
        let windows = TimeMath.findBestWindows(
            hostDate: state.hostDate,
            hostTimeZone: state.hostTimeZone,
            team: state.scoringTeam
        )
        let activeWindow = windows.first { state.hostHour >= $0.start && state.hostHour <= $0.end }
        // Thumb color reflects the score *at the cursor* — even when the
        // current window is "good" (amber), the thumb shows green if the
        // exact hostHour is in a 1.0-score zone.
        let scoreAtCursor = TimeMath.meetingScore(
            hostHour: state.hostHour,
            hostOffset: state.hostOffsetHours,
            team: state.scoringTeam,
            at: state.hostInstant
        )
        let thumbColor: Color = scoreAtCursor >= 0.95 ? v11Green
            : scoreAtCursor >= 0.5 ? v11Amber
            : .white.opacity(0.95)
        let endpoints = endpointLabels(windows: windows)

        VStack(spacing: 4) {
            track(windows: windows, activeWindow: activeWindow, thumbColor: thumbColor)
            hourLabels(endpoints: endpoints, windows: windows)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
    }

    // MARK: - Track

    private func track(
        windows: [TimeMath.Window],
        activeWindow: TimeMath.Window?,
        thumbColor: Color
    ) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                // Base rail
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 6)

                // Recommendation bands
                ForEach(Array(windows.enumerated()), id: \.offset) { (_, win) in
                    let isGreat = win.minScore >= 0.95
                    let color = isGreat ? v11Green : v11Amber
                    let isActive = activeWindow.map {
                        $0.start == win.start && $0.end == win.end
                    } ?? false

                    Group {
                        if isActive {
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: color, location: 0),
                                    .init(color: color.opacity(0.8), location: 1)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        } else {
                            Rectangle().fill(color.opacity(Self.standardBase))
                        }
                    }
                    .frame(
                        width: max(2, (win.end - win.start) / 24 * w),
                        height: 6
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .opacity(isActive ? Self.standardActive : 1)
                    .offset(x: win.start / 24 * w)
                    .animation(.easeInOut(duration: 0.2), value: isActive)
                }

                // Thumb
                thumb(thumbColor: thumbColor)
                    .offset(x: state.hostHour / 24 * w - 11.5)
            }
            .frame(height: 22)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let frac = max(0, min(1, g.location.x / w))
                        // 15-min snap across the full [0, 24] range so the
                        // thumb can park at both ends of the rail.
                        let snapped = (frac * 96).rounded() / 4
                        state.setHostHour(min(24, snapped))
                    }
            )
        }
        .frame(height: 22)
    }

    private func thumb(thumbColor: Color) -> some View {
        Circle()
            .fill(thumbColor)
            .frame(width: 18, height: 18)
            .padding(2.5)
            .background(Circle().fill(v11BgInner))
            .shadow(color: thumbColor.opacity(0.67), radius: 6, x: 0, y: 1)
            .animation(.easeInOut(duration: 0.2), value: thumbColor)
    }

    // MARK: - Hour labels under track

    private struct EndpointLabel: Identifiable {
        let id = UUID()
        let pct: Double          // x position of the label center, in 0–100
        let text: String         // "9:00" for an endpoint, "22:00–23:00" for a folded short window
        let color: Color
        let halfWidthPct: Double // approx half-width in pct, used by anchor-overlap detection
    }

    /// Wide window: label its start and end at their actual positions.
    /// Narrow window (< ~9% of the rail, so under ~2h): the two endpoint
    /// labels would overlap, so collapse them into a single centered range
    /// label like "22:00–23:00". Threshold 9% leaves a comfortable gap
    /// between separated endpoint labels at 2h+ windows.
    private static let foldThresholdPct: Double = 9

    private func endpointLabels(windows: [TimeMath.Window]) -> [EndpointLabel] {
        var labels: [EndpointLabel] = []
        for w in windows where w.minScore >= 0.95 {
            let durationPct = (w.end - w.start) / 24 * 100
            if durationPct >= Self.foldThresholdPct {
                labels.append(EndpointLabel(
                    pct: w.start / 24 * 100,
                    text: formatHHMM(w.start),
                    color: v11Green,
                    halfWidthPct: 2
                ))
                labels.append(EndpointLabel(
                    pct: w.end / 24 * 100,
                    text: formatHHMM(w.end),
                    color: v11Green,
                    halfWidthPct: 2
                ))
            } else {
                let mid = (w.start + w.end) / 2
                labels.append(EndpointLabel(
                    pct: mid / 24 * 100,
                    text: "\(formatHHMM(w.start))–\(formatHHMM(w.end))",
                    color: v11Green,
                    halfWidthPct: 5.5
                ))
            }
        }
        return labels
    }

    /// Default anchors on the hour rail. We tried 0 / 12 / 24 but the
    /// midnight/noon/midnight pattern read awkwardly when the noon mark
    /// stayed visible inside a slim recommendation block. Just 0 and 24.
    /// Each anchor still self-hides if it visually collides with an
    /// endpoint label (see `shouldShowAnchor`).
    private static let anchorHours: [Int] = [0, 24]

    private func hourLabels(endpoints: [EndpointLabel], windows: [TimeMath.Window]) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                ForEach(Self.anchorHours, id: \.self) { anchor in
                    if shouldShowAnchor(anchor, endpoints: endpoints, windows: windows) {
                        Text("\(anchor)")
                            .font(.system(size: 9).monospacedDigit())
                            .tracking(0.3)
                            .foregroundColor(.white.opacity(0.35))
                            .position(x: anchorX(anchor, width: w), y: 5)
                    }
                }
                ForEach(endpoints) { e in
                    Text(e.text)
                        .font(.system(size: 10, weight: .bold).monospacedDigit())
                        .tracking(0.2)
                        .foregroundColor(e.color)
                        .position(x: e.pct / 100 * w, y: 5)
                }
            }
        }
        .frame(height: 14)
    }

    private func anchorX(_ hour: Int, width w: CGFloat) -> CGFloat {
        switch hour {
        case 0:  return 4              // anchored just inside the left edge
        case 24: return w - 8          // and just inside the right edge
        default: return CGFloat(hour) / 24 * w
        }
    }

    private func shouldShowAnchor(_ hour: Int, endpoints: [EndpointLabel],
                                  windows: [TimeMath.Window]) -> Bool {
        let h = Double(hour)
        // Hide the anchor when it falls strictly inside a great window:
        // the green band visually owns that span, and a "0" / "24" tick
        // mid-band reads like a stray mark.
        if windows.contains(where: { $0.minScore >= 0.95 && h > $0.start && h < $0.end }) {
            return false
        }
        // Each endpoint label declares its own half-width (regular HH:MM
        // ≈ 2%, folded HH:MM–HH:MM ≈ 5.5%). The anchor itself is ~1% wide.
        let anchorPct = h / 24 * 100
        let anchorHalfWidth: Double = 1
        return !endpoints.contains {
            abs($0.pct - anchorPct) < $0.halfWidthPct + anchorHalfWidth + 0.5
        }
    }

    private func formatHHMM(_ h: Double) -> String {
        let hr = Int(h.rounded(.down))
        let min = Int(((h - Double(hr)) * 60).rounded())
        return String(format: "%d:%02d", hr, min)
    }

    private func windowColor(_ w: TimeMath.Window) -> Color {
        w.minScore >= 0.95 ? v11Green : v11Amber
    }
}

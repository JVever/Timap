import SwiftUI
import TimapCore

/// 6px-tall 24-cell hour strip with two drag handles. Visual rebuild of
/// `WorkHoursEditorD` from `settings-v1d.jsx`. Snap step is 0.25h (15 min);
/// fractional cells render the partial coverage so a 9:30 → 18:45 selection
/// looks pixel-correct rather than rounding to whole hours.
struct WorkHoursStripEditor: View {
    let workStart: Double
    let workEnd: Double
    let label: String
    let onChange: (Double, Double) -> Void

    private static let stripHeight: CGFloat = 6
    private static let hitPad: CGFloat = 10
    private static let step: Double = 0.25
    private static let coordSpace = "WorkHoursStrip"

    @State private var dragging: DragTarget? = nil
    @State private var hovering = false

    private enum DragTarget { case start, end }

    private var showHandles: Bool { hovering || dragging != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.3)
                    .foregroundColor(.white.opacity(0.5))
                Text(format(workStart))
                    .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                    .tracking(0.2)
                    .foregroundColor(.white)
                Text("—")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
                Text(format(workEnd))
                    .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                    .tracking(0.2)
                    .foregroundColor(.white)
            }

            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 1.5) {
                        ForEach(0..<24, id: \.self) { i in
                            HourCell(workStart: workStart, workEnd: workEnd, index: i)
                        }
                    }
                    .frame(height: Self.stripHeight)
                    .offset(y: Self.hitPad)

                    handle(at: workStart, target: .start, width: w)
                    handle(at: workEnd, target: .end, width: w)
                }
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
            }
            .frame(height: Self.stripHeight + Self.hitPad * 2)
            .coordinateSpace(name: Self.coordSpace)
            .padding(.top, -Self.hitPad)
            .padding(.bottom, -Self.hitPad + 4)
        }
    }

    private func format(_ h: Double) -> String {
        let hh = Int(h)
        let mm = Int((h - Double(hh)) * 60 + 0.5)
        return String(format: "%02d:%02d", hh, mm)
    }

    @ViewBuilder
    private func handle(at hour: Double, target: DragTarget, width: CGFloat) -> some View {
        let pct = hour / 24
        let active = dragging == target
        let handleWidth: CGFloat = 14
        let visW: CGFloat = 3
        let visH = Self.stripHeight + 6
        let centerX = pct * width
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.0001))
                .frame(width: handleWidth, height: Self.stripHeight + Self.hitPad * 2)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.white.opacity(active ? 1 : 0.95))
                .frame(width: visW, height: visH)
                .overlay(
                    RoundedRectangle(cornerRadius: 1.5)
                        .stroke(Color.black.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 1.5, x: 0, y: 1)
                .opacity(showHandles ? 1 : 0)
                .scaleEffect(showHandles ? 1 : 0.6)
                .animation(.easeOut(duration: 0.14), value: showHandles)
            if active {
                Text(format(hour))
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: "#161e2c"))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.5), radius: 4, y: 2)
                    .offset(y: -(Self.hitPad + visH / 2 + 8))
                    .allowsHitTesting(false)
            }
        }
        .position(x: centerX, y: Self.hitPad + Self.stripHeight / 2)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordSpace))
                .onChanged { value in
                    dragging = target
                    let hour = quantize(Double(value.location.x) / Double(width) * 24)
                    if target == .start {
                        onChange(min(hour, workEnd - Self.step), workEnd)
                    } else {
                        onChange(workStart, max(hour, workStart + Self.step))
                    }
                }
                .onEnded { _ in dragging = nil }
        )
    }

    private func quantize(_ h: Double) -> Double {
        let q = (h / Self.step).rounded() * Self.step
        return max(0, min(24, q))
    }
}

private struct HourCell: View {
    let workStart: Double
    let workEnd: Double
    let index: Int

    var body: some View {
        let i = Double(index)
        let coverage = max(0, min(workEnd, i + 1) - max(workStart, i))
        let cellStart = max(workStart, i) - i
        let cellEnd = min(workEnd, i + 1) - i
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.06))
            if coverage > 0 {
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color(red: 95/255, green: 207/255, blue: 138/255).opacity(0.65))
                        .frame(width: geo.size.width * (cellEnd - cellStart))
                        .offset(x: geo.size.width * cellStart)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 1))
    }
}

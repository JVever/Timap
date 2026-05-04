import SwiftUI
import TimapCore

private let bdAccent = Color(hex: "#ff8a5b")
private let bdGreen  = Color(hex: "#5fcf8a")
private let bdAmber  = Color(hex: "#e8b86b")

struct WorldMapView: View {
    let hostHour: Double
    let hostOffsetHours: Double
    let hostDate: Date
    let hostInstant: Date
    let cities: [CityGroup]

    private var utcHour: Double {
        var h = hostHour - hostOffsetHours
        while h < 0 { h += 24 }
        while h >= 24 { h -= 24 }
        return h
    }

    private var sunLng: Double {
        Projection.sunLongitude(utcHour: utcHour)
    }

    var body: some View {
        // Use Color.clear to anchor the aspect ratio to the parent's width,
        // then overlay the actual content. A bare GeometryReader has an
        // ideal size of 0×0, which collapses inside a VStack — that bug
        // wiped the whole map area out of the popover before this change.
        Color(hex: "#070b14")
            .aspectRatio(2.7, contentMode: .fit)
            .overlay(mapContent)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
    }

    private var mapContent: some View {
        GeometryReader { geo in
            let size = geo.size
            let placed = LabelPlacer.placeCities(cities)

            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    drawBackground(ctx: ctx, size: size)
                    drawDayGlow(ctx: ctx, size: size)
                    drawLandDots(ctx: ctx, size: size)
                    drawTerminator(ctx: ctx, size: size)
                    drawSun(ctx: ctx, size: size)
                }

                ForEach(cities) { c in
                    let pos = pinPosition(for: c, in: size)
                    PinView(group: c, hostHour: hostHour,
                            hostOffsetHours: hostOffsetHours,
                            hostInstant: hostInstant)
                        .position(x: pos.x, y: pos.y)
                }

                ForEach(placed, id: \.cityID) { item in
                    LeaderLine(item: item, mapSize: size)
                }

                ForEach(placed, id: \.cityID) { item in
                    if let c = cities.first(where: { $0.id == item.cityID }) {
                        FloatingLabel(
                            group: c,
                            placed: item,
                            mapSize: size,
                            hostHour: hostHour,
                            hostOffsetHours: hostOffsetHours
                        )
                    }
                }
            }
        }
    }

    // MARK: - Drawing

    private func drawBackground(ctx: GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: "#0a1220")))
        let dotSpacing: CGFloat = 10 * (size.width / Projection.viewWidth)
        let dotColor = Color.white.opacity(0.04)
        var x: CGFloat = 1
        while x < size.width {
            var y: CGFloat = 1
            while y < size.height {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - 0.5, y: y - 0.5, width: 1, height: 1)),
                    with: .color(dotColor)
                )
                y += dotSpacing
            }
            x += dotSpacing
        }
    }

    private func drawDayGlow(ctx: GraphicsContext, size: CGSize) {
        let sunX = (sunLng + 180) / 360 * size.width
        let cy = size.height * 0.5
        // Bigger and stronger than before — old (alpha 0.22 / r=0.64h) read as
        // "almost nothing" on the dotGrid background. New numbers are tuned so
        // the day side is unmistakably warmer than night without washing the
        // dots out: warm core ~0.55 alpha, fade extends to ~1.0× height so
        // the glow reaches the top/bottom edges.
        let r = size.height * 0.95
        let stops = Gradient(stops: [
            .init(color: Color(red: 255/255, green: 226/255, blue: 168/255).opacity(0.55), location: 0),
            .init(color: Color(red: 252/255, green: 218/255, blue: 158/255).opacity(0.32), location: 0.35),
            .init(color: Color(red: 248/255, green: 210/255, blue: 148/255).opacity(0.14), location: 0.65),
            .init(color: Color(red: 240/255, green: 200/255, blue: 130/255).opacity(0),    location: 1)
        ])
        for offset in [-size.width, 0, size.width] {
            let cx = sunX + offset
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .radialGradient(
                    stops, center: CGPoint(x: cx, y: cy),
                    startRadius: 0, endRadius: r
                )
            )
        }
    }

    private func drawLandDots(ctx: GraphicsContext, size: CGSize) {
        let scaleX = size.width / Projection.viewWidth
        let scaleY = size.height / Projection.viewHeight
        let dotR: CGFloat = max(1, 1.4 * scaleX)
        let shading = GraphicsContext.Shading.color(
            Color(red: 195/255, green: 220/255, blue: 250/255).opacity(0.85)
        )
        for d in ContinentData.landDotsViewBox {
            let cx = d.x * scaleX
            let cy = d.y * scaleY
            ctx.fill(
                Path(ellipseIn: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)),
                with: shading
            )
        }
    }

    private func drawTerminator(ctx: GraphicsContext, size: CGSize) {
        var path = Path()
        for off in [-90.0, 90.0] {
            var lng = sunLng + off
            while lng > 180 { lng -= 360 }
            while lng < -180 { lng += 360 }
            let x = (lng + 180) / 360 * size.width
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }
        ctx.stroke(
            path,
            with: .color(Color(red: 245/255, green: 235/255, blue: 210/255).opacity(0.32)),
            style: StrokeStyle(lineWidth: 1, dash: [3, 4])
        )
    }

    private func drawSun(ctx: GraphicsContext, size: CGSize) {
        let sunX = (sunLng + 180) / 360 * size.width
        let scaleY = size.height / Projection.viewHeight
        let cy: CGFloat = 28 * scaleY
        let halo1: CGFloat = 20 * scaleY
        let halo2: CGFloat = 12 * scaleY
        let core: CGFloat = max(4, 7 * scaleY)
        ctx.fill(
            Path(ellipseIn: CGRect(x: sunX - halo1, y: cy - halo1, width: halo1 * 2, height: halo1 * 2)),
            with: .color(Color(red: 253/255, green: 233/255, blue: 176/255).opacity(0.10))
        )
        ctx.fill(
            Path(ellipseIn: CGRect(x: sunX - halo2, y: cy - halo2, width: halo2 * 2, height: halo2 * 2)),
            with: .color(Color(red: 253/255, green: 233/255, blue: 176/255).opacity(0.22))
        )
        let coreShading = GraphicsContext.Shading.radialGradient(
            Gradient(stops: [
                .init(color: Color(red: 1.0, green: 0.984, blue: 0.910), location: 0),
                .init(color: Color(red: 253/255, green: 233/255, blue: 176/255), location: 0.5),
                .init(color: Color(red: 245/255, green: 212/255, blue: 128/255), location: 1)
            ]),
            center: CGPoint(x: sunX, y: cy),
            startRadius: 0, endRadius: core
        )
        ctx.fill(
            Path(ellipseIn: CGRect(x: sunX - core, y: cy - core, width: core * 2, height: core * 2)),
            with: coreShading
        )
    }

    private func pinPosition(for c: CityGroup, in size: CGSize) -> CGPoint {
        let proj = Projection.project(lng: c.lng, lat: c.lat)
        return CGPoint(
            x: proj.x / Projection.viewWidth * size.width,
            y: proj.y / Projection.viewHeight * size.height
        )
    }
}

// MARK: - Pin

private struct PinView: View {
    let group: CityGroup
    let hostHour: Double
    let hostOffsetHours: Double
    let hostInstant: Date

    var body: some View {
        let local = TimeMath.hourInTz(hostHour: hostHour, hostOffset: hostOffsetHours,
                                      targetOffset: group.offsetHours(at: hostInstant))
        let inWork = TimeMath.isInWorkHours(localHour: local, workStart: group.workStart, workEnd: group.workEnd)
        let sleeping = local < 6 || local >= 23
        let ring: Color = inWork ? bdGreen : (sleeping ? Color.white.opacity(0.4) : bdAmber)
        // Pin = inner halo (28pt) + 14pt core. The earlier 44pt outer halo
        // expanded the pin's "reserved area" so far that labels parked
        // 12pt away still ended up sitting on top of it. Dropping it lets
        // labels sit cleanly beside the pin with a tighter offset.
        ZStack {
            Circle().fill(ring.opacity(0.22)).frame(width: 28, height: 28)
            Circle().fill(Color(hex: group.colorHex))
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            if group.isHome {
                Circle().stroke(bdAccent, lineWidth: 1.5).frame(width: 22, height: 22)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Leader line

private struct LeaderLine: View {
    let item: LabelPlacer.PlacedCity
    let mapSize: CGSize

    var body: some View {
        let pinX = item.xPct / 100 * mapSize.width
        let pinY = item.yPct / 100 * mapSize.height
        let labelY = item.labelYPct / 100 * mapSize.height
        // Leader line ends just inside the label box (which sits 22pt out).
        let labelX = pinX + (item.onRight ? 16 : -16)
        // Visible leader: white@0.6 at 1.2pt + a bright dot at the pin end so
        // it's obvious the line *originates* at the city's true location.
        // Old style was 0.6pt @ 0.3 alpha — looked like a rendering glitch.
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: pinX, y: pinY))
                p.addLine(to: CGPoint(x: labelX, y: labelY))
            }
            .stroke(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 3.5, height: 3.5)
                .position(x: pinX, y: pinY)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Floating label

private struct LabelSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

private struct FloatingLabel: View {
    let group: CityGroup
    let placed: LabelPlacer.PlacedCity
    let mapSize: CGSize
    let hostHour: Double
    let hostOffsetHours: Double

    @EnvironmentObject var state: AppState
    @State private var labelSize: CGSize = .zero

    var body: some View {
        let target = group.offsetHours(at: state.hostInstant)
        let local = TimeMath.hourInTz(hostHour: hostHour, hostOffset: hostOffsetHours,
                                      targetOffset: target)
        let inWork = TimeMath.isInWorkHours(localHour: local, workStart: group.workStart, workEnd: group.workEnd)
        // Two-state: green when actually in work, otherwise a high-contrast
        // readable white. Earlier we used amber / dim white for non-work
        // states, but on the dot-grid map background those tones blended
        // with the terrain and the labels became unreadable.
        let nameColor: Color = inWork ? bdGreen : Color.white.opacity(0.95)
        let delta = TimeMath.dayDelta(hostHour: hostHour, hostOffset: hostOffsetHours,
                                      targetOffset: target)

        let pinX = placed.xPct / 100 * mapSize.width
        let labelY = placed.labelYPct / 100 * mapSize.height
        // 22pt clears the 28pt pin halo (radius 14pt) plus an 8pt buffer
        // so the label sits visually clean of the dot.
        let anchorX = pinX + (placed.onRight ? 22 : -22)
        // .position centers — convert "anchor at edge" to center coords:
        let centerX = placed.onRight
            ? anchorX + labelSize.width / 2
            : anchorX - labelSize.width / 2

        // v11: drop the leading status dot. Status is encoded in city-name
        // color and border tint instead. Day-delta rendered in Chinese
        // ("昨天" / "明天") rather than uppercased English shorthand.
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(group.displayCity(state.language))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(nameColor)
                    .tracking(0.2)
                Text(TimapFormat.hour(local, ampm: false, lang: state.language))
                    .font(.system(size: 9, weight: .semibold).monospacedDigit())
                    .foregroundColor(.white.opacity(0.85))
            }
            if delta != 0 {
                Text(L10n.relDay(delta, state.language))
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(bdAccent)
                    .tracking(0.2)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 15/255, green: 22/255, blue: 35/255).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(nameColor.opacity(0.25), lineWidth: 0.5)
                )
        )
        .fixedSize()
        .background(
            GeometryReader { g in
                Color.clear
                    .preference(key: LabelSizeKey.self, value: g.size)
            }
        )
        .onPreferenceChange(LabelSizeKey.self) { labelSize = $0 }
        .position(x: centerX, y: labelY)
        .allowsHitTesting(false)
    }
}

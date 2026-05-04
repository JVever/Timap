import Foundation

/// Position labels for pins so they don't overlap vertically.
/// Sort by Y, push subsequent labels down if they're within `minGap` percent
/// of the previous one's Y. Choose label side (left vs right of the pin)
/// based on horizontal position.
public enum LabelPlacer {
    /// City-keyed placement (one entry per CityGroup, since a city with
    /// multiple members shares geographic coordinates and should render a
    /// single pin/label, not one per member).
    public struct PlacedCity {
        public let cityID: String          // CityGroup.id (the city name)
        public let xPct: Double
        public let yPct: Double
        public let dy: Double
        public let onRight: Bool

        public init(cityID: String, xPct: Double, yPct: Double, dy: Double, onRight: Bool) {
            self.cityID = cityID
            self.xPct = xPct
            self.yPct = yPct
            self.dy = dy
            self.onRight = onRight
        }

        public var labelYPct: Double { yPct + dy }
    }

    public static func placeCities(_ cities: [CityGroup], minGap: Double = 20) -> [PlacedCity] {
        var items: [(c: CityGroup, xPct: Double, yPct: Double)] = cities.map {
            let p = Projection.project(lng: $0.lng, lat: $0.lat)
            return (
                c: $0,
                xPct: (p.x / Projection.viewWidth) * 100,
                yPct: (p.y / Projection.viewHeight) * 100
            )
        }
        items.sort { $0.yPct < $1.yPct }

        var dy: [String: Double] = [:]

        // Pass 1: prevent labels from stacking on top of each other when
        // their cities sit at similar latitudes.
        for i in 1..<items.count {
            let prev = items[i - 1]
            let cur = items[i]
            let prevTop = prev.yPct + (dy[prev.c.id] ?? 0)
            let curTop = cur.yPct + (dy[cur.c.id] ?? 0)
            if curTop - prevTop < minGap {
                dy[cur.c.id] = prevTop + minGap - cur.yPct
            }
        }

        // Pass 2: prevent a label from crossing OVER another city's pin.
        // Approximations (the percentages are wrt the map's bounding box):
        //   • label is ~16% wide, ~12% tall (city + time + 7pt padding)
        //   • pin's outer halo is ~3.5% wide on a typical popover map
        // For each label whose box intersects another city's pin box, push
        // it further down (in 4% increments) up to a few attempts.
        let labelHalfH: Double = 6
        let labelW: Double = 16
        let pinR: Double = 3.5
        for i in 0..<items.count {
            let cur = items[i]
            let onRight = cur.xPct < 55
            var labelDy = dy[cur.c.id] ?? 0
            for _ in 0..<6 {
                let labelTop = cur.yPct + labelDy - labelHalfH
                let labelBot = cur.yPct + labelDy + labelHalfH
                let labelLeft = onRight ? cur.xPct + 4 : cur.xPct - 4 - labelW
                let labelRight = labelLeft + labelW
                var collided = false
                for (j, other) in items.enumerated() where j != i {
                    let pinL = other.xPct - pinR
                    let pinR2 = other.xPct + pinR
                    let pinT = other.yPct - pinR
                    let pinB = other.yPct + pinR
                    if labelLeft < pinR2 && labelRight > pinL
                        && labelTop < pinB && labelBot > pinT {
                        // Land label entirely below this pin's halo.
                        labelDy = max(labelDy, pinB + labelHalfH + 2 - cur.yPct)
                        collided = true
                        break
                    }
                }
                if !collided { break }
            }
            dy[cur.c.id] = labelDy
        }

        return items.map { item in
            PlacedCity(
                cityID: item.c.id,
                xPct: item.xPct,
                yPct: item.yPct,
                dy: dy[item.c.id] ?? 0,
                onRight: item.xPct < 55
            )
        }
    }
}

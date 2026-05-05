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
        let labelHalfH: Double = 6
        let labelW: Double = 16
        let pinR: Double = 3.5

        struct Item {
            let c: CityGroup
            let xPct: Double
            let yPct: Double
            let onRight: Bool
            let labelLeft: Double
            let labelRight: Double
        }

        var items: [Item] = cities.map {
            let p = Projection.project(lng: $0.lng, lat: $0.lat)
            let xPct = (p.x / Projection.viewWidth) * 100
            let yPct = (p.y / Projection.viewHeight) * 100
            let onRight = xPct < 55
            let labelLeft = onRight ? xPct + 4 : xPct - 4 - labelW
            return Item(
                c: $0, xPct: xPct, yPct: yPct, onRight: onRight,
                labelLeft: labelLeft, labelRight: labelLeft + labelW
            )
        }
        items.sort { $0.yPct < $1.yPct }

        var dy: [String: Double] = [:]

        // Pass 1: prevent labels from stacking when their cities sit at
        // similar latitudes — but only push the current label down behind a
        // previous one whose label box horizontally overlaps it. Without
        // this guard, a city in the Americas (e.g. Boston) cascaded through
        // and shoved labels in Asia (e.g. Nanjing) off the bottom of the map,
        // even though their labels are on opposite sides of the world and
        // never visually conflict.
        for i in 1..<items.count {
            let cur = items[i]
            var bestPrevTop: Double? = nil
            for j in 0..<i {
                let other = items[j]
                let horizontallyOverlaps =
                    cur.labelLeft < other.labelRight && cur.labelRight > other.labelLeft
                guard horizontallyOverlaps else { continue }
                let otherTop = other.yPct + (dy[other.c.id] ?? 0)
                if bestPrevTop == nil || otherTop > bestPrevTop! {
                    bestPrevTop = otherTop
                }
            }
            if let prevTop = bestPrevTop, cur.yPct - prevTop < minGap {
                dy[cur.c.id] = prevTop + minGap - cur.yPct
            }
        }

        // Pass 2: prevent a label from crossing OVER another city's pin.
        // Approximations (percentages are wrt the map's bounding box):
        //   • label is ~16% wide, ~12% tall (city + time + 7pt padding)
        //   • pin's outer halo is ~3.5% wide on a typical popover map
        // For each label whose box intersects another city's pin box, push
        // it further down up to a few attempts.
        for i in 0..<items.count {
            let cur = items[i]
            var labelDy = dy[cur.c.id] ?? 0
            for _ in 0..<6 {
                let labelTop = cur.yPct + labelDy - labelHalfH
                let labelBot = cur.yPct + labelDy + labelHalfH
                var collided = false
                for (j, other) in items.enumerated() where j != i {
                    let pinL = other.xPct - pinR
                    let pinR2 = other.xPct + pinR
                    let pinT = other.yPct - pinR
                    let pinB = other.yPct + pinR
                    if cur.labelLeft < pinR2 && cur.labelRight > pinL
                        && labelTop < pinB && labelBot > pinT {
                        labelDy = max(labelDy, pinB + labelHalfH + 2 - cur.yPct)
                        collided = true
                        break
                    }
                }
                if !collided { break }
            }
            dy[cur.c.id] = labelDy
        }

        // Pass 3: clamp every label's center y so it stays within the map
        // viewport. This is a safety net — if pass 1+2 still push a label off
        // the bottom (e.g. a city near the equator behind a chain of others),
        // we'd rather have it slightly overlap a neighbor than disappear.
        let minY = labelHalfH
        let maxY = 100 - labelHalfH
        for item in items {
            let labelY = item.yPct + (dy[item.c.id] ?? 0)
            if labelY < minY {
                dy[item.c.id] = minY - item.yPct
            } else if labelY > maxY {
                dy[item.c.id] = maxY - item.yPct
            }
        }

        return items.map { item in
            PlacedCity(
                cityID: item.c.id,
                xPct: item.xPct,
                yPct: item.yPct,
                dy: dy[item.c.id] ?? 0,
                onRight: item.onRight
            )
        }
    }
}

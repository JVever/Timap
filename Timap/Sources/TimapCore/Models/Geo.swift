import Foundation

/// Equirectangular projection trimmed to the inhabited band:
/// 78°N (Greenland top) → -56°S (Patagonia tip). Aspect ratio ≈ 2.69:1.
/// Trimming wasted Antarctic real estate gives the popover a less squat layout.
public enum Projection {
    public static let latTop: Double = 78
    public static let latBot: Double = -56
    public static let viewWidth: Double = 1000
    public static let viewHeight: Double = 500

    /// Convert (lng, lat) to (x, y) in the 1000×500 viewBox.
    public static func project(lng: Double, lat: Double) -> (x: Double, y: Double) {
        let x = ((lng + 180) / 360) * viewWidth
        let y = ((latTop - lat) / (latTop - latBot)) * viewHeight
        return (x, y)
    }

    /// Sun longitude given UTC hour-of-day (0–24). Sun crosses 180° lng at UTC 0,
    /// 0° (Greenwich) at UTC 12. Wrapped to [-180, 180].
    public static func sunLongitude(utcHour: Double) -> Double {
        var lng = 180 - utcHour * 15
        while lng > 180 { lng -= 360 }
        while lng < -180 { lng += 360 }
        return lng
    }
}

/// Coastline polygons. Each is a closed ring of (lng, lat) anchors traced clockwise.
/// Ported verbatim from the web prototype's `bd-map-styles.jsx`.
public enum ContinentData {
    public typealias Ring = [(lng: Double, lat: Double)]

    public static let americas: Ring = [
        (-168, 60), (-165, 64), (-158, 68), (-148, 70), (-135, 69),
        (-128, 70), (-120, 71), (-110, 72), (-100, 73), (-90, 75),
        (-82, 74), (-78, 72), (-72, 67),
        (-65, 60), (-58, 56), (-55, 52), (-58, 48), (-65, 45),
        (-69, 42), (-72, 40), (-75, 37), (-77, 34), (-80, 32),
        (-81, 28), (-80, 25),
        (-82, 26),
        (-84, 30), (-89, 30), (-94, 29), (-97, 26),
        (-95, 22), (-92, 19), (-87, 18), (-87, 21),
        (-89, 16), (-91, 15),
        (-83, 10), (-80, 9), (-77, 8), (-72, 11), (-66, 11),
        (-60, 10), (-52, 5), (-50, 0),
        (-44, -3), (-38, -8), (-35, -10), (-39, -16), (-43, -23),
        (-47, -25), (-53, -35), (-58, -38), (-62, -41), (-67, -45),
        (-71, -50), (-72, -54),
        (-70, -55), (-68, -53),
        (-72, -50), (-73, -42), (-74, -36), (-72, -28), (-71, -20),
        (-75, -14), (-78, -8), (-80, -3), (-79, 1),
        (-78, 5), (-82, 8), (-85, 11), (-90, 14), (-95, 16),
        (-99, 16), (-104, 18), (-107, 24), (-110, 23),
        (-113, 28), (-115, 31), (-117, 32),
        (-121, 35), (-124, 41), (-124, 47), (-128, 51), (-132, 54),
        (-138, 58), (-148, 60), (-158, 58), (-165, 56), (-168, 60)
    ]

    public static let greenland: Ring = [
        (-50, 60), (-43, 60), (-32, 64), (-20, 70), (-22, 76),
        (-30, 81), (-40, 83), (-55, 82), (-60, 78), (-58, 72), (-50, 60)
    ]

    public static let eurasia: Ring = [
        (-9, 36), (-9, 41), (-9, 43), (-4, 47), (-2, 49),
        (2, 50), (4, 52), (7, 54),
        (10, 56), (13, 55), (18, 56), (22, 60), (24, 65),
        (27, 70), (31, 71),
        (40, 68), (50, 70), (58, 71), (68, 73), (76, 73),
        (84, 71), (90, 73), (100, 76), (108, 75), (115, 73),
        (125, 73), (135, 71), (145, 72), (155, 71), (165, 69),
        (175, 68),
        (178, 67), (177, 65),
        (170, 60), (165, 60), (160, 58),
        (155, 53), (148, 50), (142, 47), (137, 44), (132, 42),
        (129, 39), (129, 36), (128, 34), (126, 35),
        (123, 38), (120, 38), (121, 35), (120, 32),
        (121, 30), (120, 27), (119, 25), (118, 24),
        (115, 22), (113, 22), (110, 21),
        (108, 18), (107, 14), (109, 11), (106, 10),
        (105, 10), (101, 8), (100, 7),
        (103, 1),
        (99, 6), (98, 12), (94, 17),
        (91, 22), (88, 22), (85, 19), (81, 16), (80, 13),
        (80, 9), (78, 8),
        (73, 11), (73, 16), (70, 21), (68, 24),
        (62, 25), (56, 26), (52, 27), (50, 30), (48, 30),
        (49, 25), (54, 17), (52, 13), (44, 13), (42, 15),
        (39, 21), (35, 28), (34, 31),
        (36, 36), (30, 36), (27, 37),
        (22, 38), (18, 40), (12, 38), (8, 39), (3, 42),
        (-2, 36), (-9, 36)
    ]

    public static let africa: Ring = [
        (-17, 21), (-16, 16), (-13, 12), (-9, 6), (-2, 5),
        (4, 6), (9, 4), (10, 0), (12, -5), (14, -10),
        (12, -16), (14, -22), (18, -28), (20, -34),
        (25, -34), (32, -29), (36, -24),
        (40, -22), (40, -15), (42, -8), (42, -2), (43, 5),
        (51, 12), (48, 11),
        (43, 13), (38, 18), (33, 24), (25, 31), (20, 32),
        (10, 33), (0, 35), (-6, 35), (-10, 31), (-16, 25), (-17, 21)
    ]

    public static let australia: Ring = [
        (114, -22), (114, -28), (116, -33), (122, -34), (128, -32),
        (134, -33), (137, -35), (140, -38), (145, -38), (148, -38),
        (151, -34), (153, -28), (149, -22), (146, -19), (142, -11),
        (137, -12), (131, -12), (128, -15), (125, -14), (122, -17),
        (118, -20), (114, -22)
    ]

    public static let uk: Ring = [
        // Extended SE so London (~-0.1, 51.5) lands inside; the original
        // (1,53)→(-1,51) edge cut Kent off and put London in the Channel.
        (-6, 50), (-5, 53), (-3, 55), (-5, 58), (-3, 59), (0, 56),
        (2, 53), (1, 51), (-3, 50), (-6, 50)
    ]
    public static let ireland: Ring = [
        (-10, 52), (-10, 55), (-7, 55), (-6, 53), (-9, 52), (-10, 52)
    ]
    public static let japan: Ring = [
        (130, 31), (134, 33), (138, 35), (141, 36), (142, 39),
        (142, 41), (145, 44), (142, 45), (138, 41), (135, 36),
        (132, 33), (130, 31)
    ]
    public static let newZealand: Ring = [
        (173, -34), (178, -38), (177, -42), (172, -46), (167, -46),
        (170, -41), (173, -34)
    ]
    public static let indonesia: Ring = [
        (95, 5), (104, 5), (114, 4), (118, -1), (116, -7),
        (108, -8), (100, -1), (95, 5)
    ]
    public static let madagascar: Ring = [
        (44, -12), (50, -16), (50, -22), (46, -25), (43, -22), (44, -12)
    ]
    public static let newGuinea: Ring = [
        (131, -1), (142, -2), (150, -10), (144, -9), (136, -9), (131, -1)
    ]
    public static let philippines: Ring = [
        (120, 6), (125, 8), (126, 14), (122, 18), (120, 14), (120, 6)
    ]

    public static let allLands: [Ring] = [
        americas, greenland, eurasia, africa, australia,
        uk, ireland, japan, newZealand,
        indonesia, madagascar, newGuinea, philippines
    ]

    /// Ray-cast point-in-polygon test.
    public static func pointInPoly(_ x: Double, _ y: Double, _ poly: Ring) -> Bool {
        var inside = false
        var j = poly.count - 1
        for i in 0..<poly.count {
            let xi = poly[i].lng, yi = poly[i].lat
            let xj = poly[j].lng, yj = poly[j].lat
            if ((yi > y) != (yj > y)) &&
               (x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    public static func isLand(lng: Double, lat: Double) -> Bool {
        for land in allLands {
            if pointInPoly(lng, lat, land) { return true }
        }
        return false
    }

    /// All (x, y) viewBox coordinates for the dotGrid renderer. step = 2°.
    /// Computed once at first access (~5000 dots, ~30ms one-time cost).
    public static let landDotsViewBox: [(x: Double, y: Double)] = {
        var out: [(x: Double, y: Double)] = []
        var lat: Double = 76
        while lat >= -54 {
            var lng: Double = -179
            while lng <= 179 {
                if isLand(lng: lng, lat: lat) {
                    let p = Projection.project(lng: lng, lat: lat)
                    out.append((x: p.x, y: p.y))
                }
                lng += 2
            }
            lat -= 2
        }
        return out
    }()
}

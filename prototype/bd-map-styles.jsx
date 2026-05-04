// bd-map-styles.jsx — 4 distinct map background renderers.
// Each takes the same projection helper and returns SVG content rendered
// behind pins/sun/terminator. The projection is shared (equirectangular,
// 78°N..-56°S → 0..500 in viewBox 1000×500) so pin placement is consistent
// across all styles.

const BDStyles = {};

function bdProject(lng, lat) {
  const LAT_TOP = 78, LAT_BOT = -56;
  const x = ((lng + 180) / 360) * 1000;
  const y = ((LAT_TOP - lat) / (LAT_TOP - LAT_BOT)) * 500;
  return [x, y];
}
function bdProjectStr(pts) {
  return pts.map(([lng, lat]) => {
    const [x, y] = bdProject(lng, lat);
    return `${x.toFixed(1)},${y.toFixed(1)}`;
  }).join(' ');
}
function smoothPath(pts, closed = true) {
  if (pts.length < 3) return '';
  const p = pts.map(([lng, lat]) => bdProject(lng, lat));
  const n = p.length;
  let d = `M ${p[0][0].toFixed(1)} ${p[0][1].toFixed(1)}`;
  for (let i = 0; i < n - 1; i++) {
    const p0 = p[(i - 1 + n) % n];
    const p1 = p[i];
    const p2 = p[i + 1];
    const p3 = p[(i + 2) % n];
    const c1x = p1[0] + (p2[0] - p0[0]) / 6;
    const c1y = p1[1] + (p2[1] - p0[1]) / 6;
    const c2x = p2[0] - (p3[0] - p1[0]) / 6;
    const c2y = p2[1] - (p3[1] - p1[1]) / 6;
    d += ` C ${c1x.toFixed(1)} ${c1y.toFixed(1)}, ${c2x.toFixed(1)} ${c2y.toFixed(1)}, ${p2[0].toFixed(1)} ${p2[1].toFixed(1)}`;
  }
  if (closed) {
    const p0 = p[n - 2];
    const p1 = p[n - 1];
    const p2 = p[0];
    const p3 = p[1];
    const c1x = p1[0] + (p2[0] - p0[0]) / 6;
    const c1y = p1[1] + (p2[1] - p0[1]) / 6;
    const c2x = p2[0] - (p3[0] - p1[0]) / 6;
    const c2y = p2[1] - (p3[1] - p1[1]) / 6;
    d += ` C ${c1x.toFixed(1)} ${c1y.toFixed(1)}, ${c2x.toFixed(1)} ${c2y.toFixed(1)}, ${p2[0].toFixed(1)} ${p2[1].toFixed(1)} Z`;
  }
  return d;
}

const COAST = {
  americas: [
    [-168, 60], [-165, 64], [-158, 68], [-148, 70], [-135, 69],
    [-128, 70], [-120, 71], [-110, 72], [-100, 73], [-90, 75],
    [-82, 74], [-78, 72], [-72, 67],
    [-65, 60], [-58, 56], [-55, 52], [-58, 48], [-65, 45],
    [-69, 42], [-72, 40], [-75, 37], [-77, 34], [-80, 32],
    [-81, 28], [-80, 25],
    [-82, 26],
    [-84, 30], [-89, 30], [-94, 29], [-97, 26],
    [-95, 22], [-92, 19], [-87, 18], [-87, 21],
    [-89, 16], [-91, 15],
    [-83, 10], [-80, 9], [-77, 8], [-72, 11], [-66, 11],
    [-60, 10], [-52, 5], [-50, 0],
    [-44, -3], [-38, -8], [-35, -10], [-39, -16], [-43, -23],
    [-47, -25], [-53, -35], [-58, -38], [-62, -41], [-67, -45],
    [-71, -50], [-72, -54],
    [-70, -55], [-68, -53],
    [-72, -50], [-73, -42], [-74, -36], [-72, -28], [-71, -20],
    [-75, -14], [-78, -8], [-80, -3], [-79, 1],
    [-78, 5], [-82, 8], [-85, 11], [-90, 14], [-95, 16],
    [-99, 16], [-104, 18], [-107, 24], [-110, 23],
    [-113, 28], [-115, 31], [-117, 32],
    [-121, 35], [-124, 41], [-124, 47], [-128, 51], [-132, 54],
    [-138, 58], [-148, 60], [-158, 58], [-165, 56], [-168, 60],
  ],

  greenland: [
    [-50, 60], [-43, 60], [-32, 64], [-20, 70], [-22, 76],
    [-30, 81], [-40, 83], [-55, 82], [-60, 78], [-58, 72], [-50, 60],
  ],

  eurasia: [
    [-9, 36], [-9, 41], [-9, 43], [-4, 47], [-2, 49],
    [2, 50], [4, 52], [7, 54],
    [10, 56], [13, 55], [18, 56], [22, 60], [24, 65],
    [27, 70], [31, 71],
    [40, 68], [50, 70], [58, 71], [68, 73], [76, 73],
    [84, 71], [90, 73], [100, 76], [108, 75], [115, 73],
    [125, 73], [135, 71], [145, 72], [155, 71], [165, 69],
    [175, 68],
    [178, 67], [177, 65],
    [170, 60], [165, 60], [160, 58],
    [155, 53], [148, 50], [142, 47], [137, 44], [132, 42],
    [129, 39], [129, 36], [128, 34], [126, 35],
    [123, 38], [120, 38], [121, 35], [120, 32],
    [121, 30], [120, 27], [119, 25], [118, 24],
    [115, 22], [113, 22], [110, 21],
    [108, 18], [107, 14], [109, 11], [106, 10],
    [105, 10], [101, 8], [100, 7],
    [103, 1],
    [99, 6], [98, 12], [94, 17],
    [91, 22], [88, 22], [85, 19], [81, 16], [80, 13],
    [80, 9], [78, 8],
    [73, 11], [73, 16], [70, 21], [68, 24],
    [62, 25], [56, 26], [52, 27], [50, 30], [48, 30],
    [49, 25], [54, 17], [52, 13], [44, 13], [42, 15],
    [39, 21], [35, 28], [34, 31],
    [36, 36], [30, 36], [27, 37],
    [22, 38], [18, 40], [12, 38], [8, 39], [3, 42],
    [-2, 36], [-9, 36],
  ],

  africa: [
    [-17, 21], [-16, 16], [-13, 12], [-9, 6], [-2, 5],
    [4, 6], [9, 4], [10, 0], [12, -5], [14, -10],
    [12, -16], [14, -22], [18, -28], [20, -34],
    [25, -34], [32, -29], [36, -24],
    [40, -22], [40, -15], [42, -8], [42, -2], [43, 5],
    [51, 12], [48, 11],
    [43, 13], [38, 18], [33, 24], [25, 31], [20, 32],
    [10, 33], [0, 35], [-6, 35], [-10, 31], [-16, 25], [-17, 21],
  ],

  australia: [
    [114, -22], [114, -28], [116, -33], [122, -34], [128, -32],
    [134, -33], [137, -35], [140, -38], [145, -38], [148, -38],
    [151, -34], [153, -28], [149, -22], [146, -19], [142, -11],
    [137, -12], [131, -12], [128, -15], [125, -14], [122, -17],
    [118, -20], [114, -22],
  ],

  uk: [
    [-6, 50], [-5, 53], [-3, 55], [-5, 58], [-3, 59], [0, 56],
    [1, 53], [-1, 51], [-3, 50], [-6, 50],
  ],
  ireland: [
    [-10, 52], [-10, 55], [-7, 55], [-6, 53], [-9, 52], [-10, 52],
  ],

  japan: [
    [130, 31], [134, 33], [138, 35], [141, 36], [142, 39],
    [142, 41], [145, 44], [142, 45], [138, 41], [135, 36],
    [132, 33], [130, 31],
  ],
  newZealand: [
    [173, -34], [178, -38], [177, -42], [172, -46], [167, -46],
    [170, -41], [173, -34],
  ],
  indonesia: [
    [95, 5], [104, 5], [114, 4], [118, -1], [116, -7],
    [108, -8], [100, -1], [95, 5],
  ],
  madagascar: [
    [44, -12], [50, -16], [50, -22], [46, -25], [43, -22], [44, -12],
  ],
  newGuinea: [
    [131, -1], [142, -2], [150, -10], [144, -9], [136, -9], [131, -1],
  ],
  philippines: [
    [120, 6], [125, 8], [126, 14], [122, 18], [120, 14], [120, 6],
  ],
};

const ALL_LANDS = Object.values(COAST);

BDStyles.geographic = function StyleGeographic() {
  return (
    <g
      fill="rgba(180,205,230,0.26)"
      stroke="rgba(200,225,250,0.55)"
      strokeWidth="0.9"
      strokeLinejoin="round"
      strokeLinecap="round"
    >
      {ALL_LANDS.map((pts, i) => (
        <polygon key={i} points={bdProjectStr(pts)} />
      ))}
    </g>
  );
};

function pointInPoly(x, y, poly) {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, yi] = poly[i], [xj, yj] = poly[j];
    if (((yi > y) !== (yj > y)) && (x < ((xj - xi) * (y - yi)) / (yj - yi) + xi)) {
      inside = !inside;
    }
  }
  return inside;
}
function isLand(lng, lat) {
  for (const land of ALL_LANDS) {
    if (pointInPoly(lng, lat, land)) return true;
  }
  return false;
}
BDStyles.dotGrid = function StyleDotGrid() {
  const dots = [];
  const step = 2;
  for (let lat = 76; lat >= -54; lat -= step) {
    for (let lng = -179; lng <= 179; lng += step) {
      if (isLand(lng, lat)) {
        const [x, y] = bdProject(lng, lat);
        dots.push([x, y]);
      }
    }
  }
  return (
    <g fill="rgba(195,220,250,0.85)">
      {dots.map(([x, y], i) => (
        <circle key={i} cx={x.toFixed(1)} cy={y.toFixed(1)} r="1.4" />
      ))}
    </g>
  );
};

BDStyles.graticule = function StyleGraticule() {
  const xOf = (lng) => bdProject(lng, 0)[0];
  const yOf = (lat) => bdProject(0, lat)[1];
  const meridians = [-180, -150, -120, -90, -60, -30, 0, 30, 60, 90, 120, 150, 180];
  const parallels = [60, 30, 0, -30];
  return (
    <>
      <g stroke="rgba(190,215,240,0.13)" strokeWidth="0.5" fill="none">
        {meridians.map(lng => {
          const x = xOf(lng);
          const major = lng % 60 === 0;
          return <line key={lng} x1={x} x2={x} y1="0" y2="500"
            strokeOpacity={major ? 0.32 : 0.13}
            strokeDasharray={major ? '' : '2 4'} />;
        })}
        {parallels.map(lat => {
          const y = yOf(lat);
          const major = lat === 0;
          return <line key={lat} x1="0" x2="1000" y1={y} y2={y}
            strokeOpacity={major ? 0.32 : 0.13}
            strokeDasharray={major ? '' : '2 4'} />;
        })}
      </g>
      <text x="6" y={yOf(0) - 4}
        fontFamily="ui-monospace, Menlo, monospace"
        fontSize="9" fill="rgba(190,215,240,0.4)">EQUATOR</text>
      <text x={xOf(0) + 4} y="14"
        fontFamily="ui-monospace, Menlo, monospace"
        fontSize="9" fill="rgba(190,215,240,0.4)">0°</text>
    </>
  );
};

BDStyles.blobs = function StyleBlobs() {
  const blobs = [
    { lng: -100, lat: 48, rxDeg: 30, ryDeg: 22, rot: 0 },
    { lng: -60, lat: -20, rxDeg: 14, ryDeg: 26, rot: -15 },
    { lng: 80, lat: 50, rxDeg: 70, ryDeg: 22, rot: 0 },
    { lng: 90, lat: 22, rxDeg: 22, ryDeg: 14, rot: 0 },
    { lng: 5, lat: 48, rxDeg: 14, ryDeg: 12, rot: 0 },
    { lng: 18, lat: 5, rxDeg: 18, ryDeg: 30, rot: 0 },
    { lng: 134, lat: -25, rxDeg: 18, ryDeg: 9, rot: 0 },
    { lng: -42, lat: 73, rxDeg: 14, ryDeg: 9, rot: 0 },
  ];
  return (
    <g fill="rgba(170,195,220,0.18)" stroke="rgba(190,215,240,0.3)" strokeWidth="0.6">
      {blobs.map((b, i) => {
        const [cx, cy] = bdProject(b.lng, b.lat);
        const [, yTop] = bdProject(b.lng, b.lat + b.ryDeg);
        const [xRight] = bdProject(b.lng + b.rxDeg, b.lat);
        const rx = Math.abs(xRight - cx);
        const ry = Math.abs(cy - yTop);
        return (
          <ellipse key={i} cx={cx} cy={cy} rx={rx} ry={ry}
            transform={b.rot ? `rotate(${b.rot} ${cx} ${cy})` : undefined} />
        );
      })}
    </g>
  );
};

window.BDStyles = BDStyles;

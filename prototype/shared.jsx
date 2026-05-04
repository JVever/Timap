// shared.jsx — common data + utilities
const TEAM = [
  { id: 'me', name: 'You', role: 'Product', city: 'Beijing', country: 'CN', flag: '🇨🇳',
    tz: 'Asia/Shanghai', offset: 8, lat: 39.9, lng: 116.4,
    workStart: 9, workEnd: 23, color: '#c96442', isMe: true },
  { id: 'mira', name: 'Mira Chen', role: 'Design Lead', city: 'Seattle', country: 'US', flag: '🇺🇸',
    tz: 'America/Los_Angeles', offset: -7, lat: 47.6, lng: -122.3,
    workStart: 9, workEnd: 23, color: '#3b7a8c' },
  { id: 'jordan', name: 'Jordan Park', role: 'Engineer', city: 'Boston', country: 'US', flag: '🇺🇸',
    tz: 'America/New_York', offset: -4, lat: 42.4, lng: -71.1,
    workStart: 9, workEnd: 23, color: '#7a5ca8' },
  { id: 'sam', name: 'Sam Okafor', role: 'PM', city: 'Chicago', country: 'US', flag: '🇺🇸',
    tz: 'America/Chicago', offset: -5, lat: 41.9, lng: -87.6,
    workStart: 9, workEnd: 23, color: '#c8924a' },
];

function hourInTz(hostHour, hostOffset, targetOffset) {
  let h = hostHour - hostOffset + targetOffset;
  while (h < 0) h += 24;
  while (h >= 24) h -= 24;
  return h;
}
function dayDelta(hostHour, hostOffset, targetOffset) {
  const raw = hostHour - hostOffset + targetOffset;
  if (raw < 0) return -1;
  if (raw >= 24) return 1;
  return 0;
}
function formatHour(h, ampm = true) {
  const hour = Math.floor(h);
  const min = Math.round((h - hour) * 60);
  if (ampm) {
    const period = hour < 12 || hour === 24 ? 'AM' : 'PM';
    let h12 = hour % 12; if (h12 === 0) h12 = 12;
    return `${h12}:${String(min).padStart(2, '0')} ${period}`;
  }
  return `${String(hour).padStart(2, '0')}:${String(min).padStart(2, '0')}`;
}
function formatHourShort(h) {
  const hour = Math.floor(h) % 24;
  const period = hour < 12 ? 'a' : 'p';
  let h12 = hour % 12; if (h12 === 0) h12 = 12;
  return `${h12}${period}`;
}
function isInWorkHours(localHour, workStart, workEnd) {
  return localHour >= workStart && localHour < workEnd;
}
function meetingScore(hostHour, team) {
  let score = 1;
  for (const p of team) {
    const h = hourInTz(hostHour, 8, p.offset);
    const inWork = h >= p.workStart && h < p.workEnd;
    if (inWork) continue;
    const distStart = Math.min(Math.abs(h - p.workStart), 24 - Math.abs(h - p.workStart));
    const distEnd = Math.min(Math.abs(h - p.workEnd), 24 - Math.abs(h - p.workEnd));
    const dist = Math.min(distStart, distEnd);
    if (h < 6.5 || h >= 23.5) { score = 0; continue; }
    if (dist <= 0.5) { score = Math.min(score, 0.7); continue; }
    score = 0;
  }
  return score;
}
function findBestWindows(team) {
  const slots = [];
  for (let h = 0; h < 24; h += 0.5) slots.push({ h, score: meetingScore(h, team) });
  const windows = [];
  let cur = null;
  for (const s of slots) {
    if (s.score >= 0.5) {
      if (!cur) cur = { start: s.h, end: s.h + 0.5, minScore: s.score };
      else { cur.end = s.h + 0.5; cur.minScore = Math.min(cur.minScore, s.score); }
    } else if (cur) { windows.push(cur); cur = null; }
  }
  if (cur) windows.push(cur);
  return windows.sort((a, b) => b.minScore - a.minScore);
}

const WEEKDAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

function dateAt(hostDate, delta) {
  const d = new Date(hostDate);
  d.setDate(d.getDate() + delta);
  return d;
}
function fmtDate(d) {
  return `${WEEKDAYS[d.getDay()]} · ${MONTHS[d.getMonth()]} ${d.getDate()}`;
}
function fmtDateShort(d) {
  return `${WEEKDAYS[d.getDay()].toUpperCase()} ${d.getDate()}`;
}
function relDayLabel(delta) {
  if (delta === 0) return 'Today';
  if (delta === 1) return 'Tomorrow';
  if (delta === -1) return 'Yesterday';
  return delta > 0 ? `+${delta}d` : `${delta}d`;
}

Object.assign(window, {
  TEAM, hourInTz, dayDelta, formatHour, formatHourShort,
  isInWorkHours, meetingScore, findBestWindows,
  dateAt, fmtDate, fmtDateShort, relDayLabel, WEEKDAYS, MONTHS,
});

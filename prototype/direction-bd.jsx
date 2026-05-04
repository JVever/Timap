// direction-bd.jsx — combined map + matrix view

const BD_ACCENT = '#ff8a5b';
const BD_BG = '#0d1420';
const BD_GREEN = '#7ed957';
const BD_AMBER = '#f5b53d';

function bdLngLatToXY(lng, lat, w = 1000, h = 500) {
  const LAT_TOP = 78;
  const LAT_BOT = -56;
  const x = ((lng + 180) / 360) * w;
  const y = ((LAT_TOP - lat) / (LAT_TOP - LAT_BOT)) * h;
  return [x, y];
}
function bdSunLng(utcHour) {
  let lng = 180 - utcHour * 15;
  while (lng > 180) lng -= 360;
  while (lng < -180) lng += 360;
  return lng;
}

function placeLabels(team) {
  const items = team.map(p => {
    const [x, y] = bdLngLatToXY(p.lng, p.lat);
    return { p, x, y, xPct: (x / 1000) * 100, yPct: (y / 500) * 100, side: 'right', leaderY: (y / 500) * 100, dy: 0 };
  });
  items.sort((a, b) => a.yPct - b.yPct);
  const minGap = 14;
  for (let i = 1; i < items.length; i++) {
    const prev = items[i - 1];
    const cur = items[i];
    const prevTop = prev.yPct + prev.dy;
    if (cur.yPct - prevTop < minGap) {
      cur.dy = prevTop + minGap - cur.yPct;
    }
  }
  for (const it of items) {
    it.side = it.xPct < 55 ? 'right' : 'left';
  }
  return items;
}

function BD_Map({ hostHour, hostDate, team, mapStyle = 'dotGrid' }) {
  let utcHour = hostHour - 8;
  while (utcHour < 0) utcHour += 24;
  const sunLng = bdSunLng(utcHour);
  const xOf = (lng) => ((lng + 180) / 360) * 1000;

  const placed = placeLabels(team);

  return (
    <div style={{
      position: 'relative', width: '100%', aspectRatio: '2.7 / 1',
      borderRadius: 8, overflow: 'hidden', background: '#070b14',
      border: '0.5px solid rgba(255,255,255,0.08)',
    }}>
      <svg viewBox="0 0 1000 500" preserveAspectRatio="none"
        style={{ display: 'block', width: '100%', height: '100%' }}>
        <defs>
          <radialGradient id="bd-sun" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="#fffbe8" />
            <stop offset="50%" stopColor="#fde9b0" />
            <stop offset="100%" stopColor="#f5d480" />
          </radialGradient>
          <pattern id="bd-dots" width="10" height="10" patternUnits="userSpaceOnUse">
            <circle cx="1" cy="1" r="0.5" fill="rgba(255,255,255,0.04)" />
          </pattern>
        </defs>
        <rect width="1000" height="500" fill="#0a1220" />
        <rect width="1000" height="500" fill="url(#bd-dots)" />

        <defs>
          {[-1000, 0, 1000].map(off => {
            const cx = xOf(sunLng) + off;
            return (
              <radialGradient key={off} id={`bd-day-${off}`}
                gradientUnits="userSpaceOnUse"
                cx={cx} cy={250} r={320}>
                <stop offset="0%" stopColor="rgba(250,240,215,0.18)" />
                <stop offset="55%" stopColor="rgba(245,235,210,0.06)" />
                <stop offset="100%" stopColor="rgba(240,230,200,0)" />
              </radialGradient>
            );
          })}
        </defs>
        {[-1000, 0, 1000].map(off => (
          <rect key={off}
            x={0} y={0} width={1000} height={500}
            fill={`url(#bd-day-${off})`} />
        ))}

        {(() => {
          const Style = (window.BDStyles && window.BDStyles[mapStyle]) || (window.BDStyles && window.BDStyles.geographic);
          return Style ? <Style /> : null;
        })()}

        {[-90, 90].map(off => {
          let lng = sunLng + off;
          while (lng > 180) lng -= 360;
          while (lng < -180) lng += 360;
          return <line key={off} x1={xOf(lng)} x2={xOf(lng)} y1="0" y2="500"
            stroke="rgba(245,235,210,0.32)" strokeWidth="1" strokeDasharray="3 4" />;
        })}

        <g>
          <circle cx={xOf(sunLng)} cy={28} r="20" fill="rgba(253,233,176,0.10)" />
          <circle cx={xOf(sunLng)} cy={28} r="12" fill="rgba(253,233,176,0.22)" />
          <circle cx={xOf(sunLng)} cy={28} r="7" fill="url(#bd-sun)" />
        </g>

        {team.map(p => {
          const [x, y] = bdLngLatToXY(p.lng, p.lat);
          const localH = hourInTz(hostHour, 8, p.offset);
          const inWork = isInWorkHours(localH, p.workStart, p.workEnd);
          const sleeping = localH < 6 || localH >= 23;
          const ring = inWork ? BD_GREEN : sleeping ? 'rgba(255,255,255,0.4)' : BD_AMBER;
          return (
            <g key={p.id} transform={`translate(${x},${y})`}>
              <circle r="22" fill={ring} opacity="0.12" />
              <circle r="14" fill={ring} opacity="0.22" />
              <circle r="7" fill={p.color} stroke="#fff" strokeWidth="1.5" />
              {p.isMe && <circle r="11" fill="none" stroke={BD_ACCENT} strokeWidth="1.5" />}
            </g>
          );
        })}

        {placed.map(({ p, xPct, yPct, dy, side }) => {
          const lx = side === 'right' ? xPct + 4 : xPct - 4;
          const ly1 = yPct;
          const ly2 = yPct + dy;
          return (
            <g key={'l' + p.id} stroke="rgba(255,255,255,0.3)" strokeWidth="0.6" fill="none">
              <line x1={`${xPct}%`} y1={`${ly1}%`} x2={`${lx}%`} y2={`${ly2}%`} vectorEffect="non-scaling-stroke" />
            </g>
          );
        })}
      </svg>

      {placed.map(({ p, xPct, yPct, dy, side }) => {
        const localH = hourInTz(hostHour, 8, p.offset);
        const inWork = isInWorkHours(localH, p.workStart, p.workEnd);
        const sleeping = localH < 6 || localH >= 23;
        const delta = dayDelta(hostHour, 8, p.offset);
        const labelLeft = side === 'right';
        return (
          <div key={p.id} style={{
            position: 'absolute',
            left: `calc(${xPct}% + ${labelLeft ? 12 : -12}px)`,
            top: `${yPct + dy}%`,
            transform: `translate(${labelLeft ? '0' : '-100%'}, -50%)`,
            background: 'rgba(15,22,35,0.92)',
            backdropFilter: 'blur(10px)',
            border: '0.5px solid rgba(255,255,255,0.14)',
            borderRadius: 5,
            padding: '3px 6px',
            fontSize: 9.5,
            fontFamily: '-apple-system, BlinkMacSystemFont, system-ui, sans-serif',
            color: 'rgba(255,255,255,0.95)',
            whiteSpace: 'nowrap',
            pointerEvents: 'none',
            opacity: sleeping ? 0.7 : 1,
            lineHeight: 1.25,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
              <div style={{
                width: 4, height: 4, borderRadius: '50%',
                background: inWork ? BD_GREEN : sleeping ? 'rgba(255,255,255,0.4)' : BD_AMBER,
              }} />
              <span style={{ fontWeight: 600 }}>{p.city}</span>
              <span style={{ color: 'rgba(255,255,255,0.65)', fontVariantNumeric: 'tabular-nums' }}>
                {formatHour(localH)}
              </span>
            </div>
            {delta !== 0 && (
              <div style={{
                fontSize: 8, color: BD_ACCENT, fontWeight: 600,
                marginTop: 1, letterSpacing: 0.2,
              }}>
                {relDayLabel(delta)}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

function BD_PersonRow({ p, hostHour, hostDate, onPickTime, selected = true, onToggle }) {
  const localH = hourInTz(hostHour, 8, p.offset);
  const inWork = isInWorkHours(localH, p.workStart, p.workEnd);
  const sleeping = localH < 6 || localH >= 23;
  const delta = dayDelta(hostHour, 8, p.offset);
  const localDate = dateAt(hostDate, delta);
  const statusColor = inWork ? BD_GREEN : sleeping ? 'rgba(255,255,255,0.35)' : BD_AMBER;

  const cells = [];
  for (let i = 0; i < 24; i++) {
    const lh = hourInTz(i, 8, p.offset);
    const isWork = isInWorkHours(lh, p.workStart, p.workEnd);
    const isSleep = lh < 6 || lh >= 23;
    let bg = 'rgba(255,255,255,0.06)';
    if (isWork) bg = 'rgba(126,217,87,0.45)';
    else if (isSleep) bg = 'rgba(255,255,255,0.02)';
    cells.push(
      <div key={i} style={{
        flex: 1,
        background: bg,
        borderRight: i < 23 ? '0.5px solid rgba(0,0,0,0.4)' : 'none',
      }} />
    );
  }

  const handleClick = (e) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const frac = Math.max(0, Math.min(1, x / rect.width));
    const h = Math.round(frac * 48) / 2;
    onPickTime(Math.min(23.5, h));
  };

  return (
    <div style={{
      padding: '7px 12px',
      borderBottom: '0.5px solid rgba(255,255,255,0.05)',
      opacity: selected ? 1 : 0.5,
      transition: 'opacity .15s',
    }}>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8,
        marginBottom: 4,
      }}>
        <button
          onClick={() => onToggle && onToggle(p.id)}
          aria-label={selected ? `Hide ${p.city}` : `Show ${p.city}`}
          title={selected ? 'Click to hide' : 'Click to include'}
          style={{
            position: 'relative',
            width: 20, height: 20, borderRadius: '50%',
            background: selected ? p.color : 'transparent',
            color: '#fff',
            border: selected ? 'none' : `1px dashed ${p.color}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 9, fontWeight: 700,
            boxShadow: p.isMe && selected ? `0 0 0 1.5px ${BD_ACCENT}` : 'none',
            flexShrink: 0, padding: 0, cursor: p.isMe ? 'default' : 'pointer',
            opacity: selected ? 1 : 0.6,
          }}>
          <span style={{ color: selected ? '#fff' : p.color }}>
            {p.name.split(' ').map(n => n[0]).slice(0, 2).join('')}
          </span>
        </button>
        <div style={{
          fontSize: 11.5, fontWeight: 600,
          color: 'rgba(255,255,255,0.95)',
          textDecoration: selected ? 'none' : 'line-through',
          textDecorationColor: 'rgba(255,255,255,0.3)',
        }}>
          {p.city}
        </div>
        <div style={{
          fontSize: 10, color: 'rgba(255,255,255,0.4)',
          fontFamily: 'ui-monospace, "SF Mono", Menlo, monospace',
        }}>
          UTC{p.offset >= 0 ? '+' : ''}{p.offset}
        </div>
        <div style={{ flex: 1 }} />
        <div style={{
          fontSize: 12, fontWeight: 600,
          color: statusColor,
          fontVariantNumeric: 'tabular-nums',
          fontFamily: 'ui-monospace, "SF Mono", Menlo, monospace',
        }}>
          {formatHour(localH, false)}
        </div>
        <div style={{
          fontSize: 9.5, fontWeight: delta !== 0 ? 700 : 500,
          color: delta !== 0 ? BD_ACCENT : 'rgba(255,255,255,0.5)',
          minWidth: 56, textAlign: 'right',
        }}>
          {delta !== 0 ? relDayLabel(delta) : fmtDateShort(localDate)}
        </div>
      </div>

      <div
        onClick={handleClick}
        style={{
          position: 'relative', height: 16, borderRadius: 3,
          overflow: 'hidden', display: 'flex',
          cursor: 'pointer',
        }}>
        {cells}
        <div style={{
          position: 'absolute', top: -2, bottom: -2,
          left: `${(hostHour / 24) * 100}%`,
          width: 2, marginLeft: -1,
          background: BD_ACCENT,
          boxShadow: `0 0 6px ${BD_ACCENT}`,
          pointerEvents: 'none',
        }} />
      </div>
    </div>
  );
}

function BD_Settings({ team, setTeam, onClose }) {
  return (
    <div style={{
      position: 'absolute',
      inset: 0,
      background: 'rgba(8,12,20,0.96)',
      backdropFilter: 'blur(20px)',
      zIndex: 30,
      display: 'flex', flexDirection: 'column',
      borderRadius: 14,
      overflow: 'hidden',
    }}>
      <div style={{
        padding: '12px 14px',
        borderBottom: '0.5px solid rgba(255,255,255,0.1)',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <div>
          <div style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)', fontWeight: 600, letterSpacing: 0.5 }}>
            SETTINGS
          </div>
          <div style={{ fontSize: 15, fontWeight: 600, marginTop: 2 }}>
            Working hours
          </div>
        </div>
        <button onClick={onClose} style={{
          background: 'rgba(255,255,255,0.1)', border: 'none',
          color: '#fff', fontSize: 12, fontWeight: 500,
          padding: '5px 12px', borderRadius: 5, cursor: 'pointer',
        }}>Done</button>
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: '8px 14px' }}>
        {team.map(p => (
          <div key={p.id} style={{
            padding: '10px 0',
            borderBottom: '0.5px solid rgba(255,255,255,0.06)',
            display: 'flex', alignItems: 'center', gap: 10,
          }}>
            <div style={{
              width: 24, height: 24, borderRadius: '50%',
              background: p.color, color: '#fff',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 10, fontWeight: 700, flexShrink: 0,
            }}>
              {p.name.split(' ').map(n => n[0]).slice(0, 2).join('')}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 12, fontWeight: 600, color: 'rgba(255,255,255,0.95)' }}>
                {p.city} <span style={{ color: 'rgba(255,255,255,0.45)', fontWeight: 400 }}>· {p.name}</span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 6 }}>
                <select value={p.workStart}
                  onChange={(e) => setTeam(team.map(t => t.id === p.id ? { ...t, workStart: parseInt(e.target.value) } : t))}
                  style={{
                    background: 'rgba(255,255,255,0.08)', color: '#fff',
                    border: '0.5px solid rgba(255,255,255,0.15)', borderRadius: 4,
                    padding: '3px 6px', fontSize: 11, fontFamily: 'inherit',
                  }}>
                  {Array.from({ length: 24 }, (_, i) => (
                    <option key={i} value={i} style={{ background: '#1a2436' }}>
                      {formatHourShort(i)}
                    </option>
                  ))}
                </select>
                <span style={{ fontSize: 10, color: 'rgba(255,255,255,0.5)' }}>to</span>
                <select value={p.workEnd}
                  onChange={(e) => setTeam(team.map(t => t.id === p.id ? { ...t, workEnd: parseInt(e.target.value) } : t))}
                  style={{
                    background: 'rgba(255,255,255,0.08)', color: '#fff',
                    border: '0.5px solid rgba(255,255,255,0.15)', borderRadius: 4,
                    padding: '3px 6px', fontSize: 11, fontFamily: 'inherit',
                  }}>
                  {Array.from({ length: 24 }, (_, i) => (
                    <option key={i + 1} value={i + 1} style={{ background: '#1a2436' }}>
                      {formatHourShort(i + 1)}
                    </option>
                  ))}
                </select>
                <span style={{
                  marginLeft: 'auto',
                  fontSize: 10, color: 'rgba(255,255,255,0.4)',
                  fontFamily: 'ui-monospace, monospace',
                }}>
                  {p.workEnd - p.workStart}h
                </span>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function DirBD({ mapStyle = 'dotGrid' }) {
  const [hostHour, setHostHour] = React.useState(10);
  const [team, setTeam] = React.useState(() => TEAM.map(p => ({ ...p })));
  const [selected, setSelected] = React.useState(() => new Set(TEAM.map(p => p.id)));
  const [showSettings, setShowSettings] = React.useState(false);
  const hostDate = new Date(2026, 4, 4);
  const activeTeam = team.filter(p => selected.has(p.id));
  const score = meetingScore(hostHour, activeTeam);
  const windows = findBestWindows(activeTeam.length ? activeTeam : team);
  const ordered = [...team].sort((a, b) => {
    const sa = selected.has(a.id) ? 1 : 0;
    const sb = selected.has(b.id) ? 1 : 0;
    if (sa !== sb) return sb - sa;
    return (b.isMe ? 1 : 0) - (a.isMe ? 1 : 0);
  });

  const toggle = (id) => {
    setSelected(prev => {
      const next = new Set(prev);
      const p = team.find(t => t.id === id);
      if (p && p.isMe) return prev;
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  };

  const statusColor = score >= 0.95 ? BD_GREEN : score >= 0.5 ? BD_AMBER : '#e85a5a';
  const statusText = score >= 0.95 ? 'All in core hours'
    : score >= 0.5 ? 'Workable' : 'Someone is asleep';

  return (
    <div style={{
      width: 596,
      background: 'rgba(13,20,32,0.96)',
      backdropFilter: 'blur(40px) saturate(180%)',
      WebkitBackdropFilter: 'blur(40px) saturate(180%)',
      borderRadius: 14,
      border: '0.5px solid rgba(255,255,255,0.1)',
      boxShadow: '0 20px 60px rgba(0,0,0,0.5), inset 0 1px 0 rgba(255,255,255,0.04)',
      fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro", system-ui, sans-serif',
      color: 'rgba(255,255,255,0.95)',
      overflow: 'hidden',
      position: 'relative',
    }}>
      <div style={{
        position: 'absolute', top: -7, left: 28,
        width: 14, height: 14,
        background: 'rgba(13,20,32,0.96)',
        borderTop: '0.5px solid rgba(255,255,255,0.1)',
        borderLeft: '0.5px solid rgba(255,255,255,0.1)',
        transform: 'rotate(45deg)',
      }} />

      <div style={{
        padding: '10px 14px',
        borderBottom: '0.5px solid rgba(255,255,255,0.06)',
        display: 'flex', alignItems: 'center', gap: 10,
      }}>
        <div style={{ minWidth: 0 }}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, whiteSpace: 'nowrap' }}>
            <span style={{
              fontSize: 22, fontWeight: 600, fontVariantNumeric: 'tabular-nums',
              letterSpacing: -0.3,
            }}>
              {formatHour(hostHour)}
            </span>
            <span style={{
              fontSize: 10.5, color: 'rgba(255,255,255,0.5)',
              letterSpacing: 0.2,
            }}>
              {fmtDate(hostDate)}
            </span>
            <span style={{
              fontSize: 9.5, color: 'rgba(255,255,255,0.35)',
              padding: '1px 5px',
              border: '0.5px solid rgba(255,255,255,0.12)',
              borderRadius: 3,
              fontWeight: 600, letterSpacing: 0.4,
            }}>BJS</span>
          </div>
        </div>

        <div style={{
          display: 'flex', alignItems: 'center', gap: 5,
          padding: '3px 8px',
          background: `${statusColor}1f`,
          border: `0.5px solid ${statusColor}50`,
          borderRadius: 4,
          fontSize: 10.5, fontWeight: 600, color: statusColor,
          whiteSpace: 'nowrap',
        }}>
          <div style={{ width: 5, height: 5, borderRadius: '50%', background: statusColor }} />
          {statusText}
        </div>

        <div style={{ flex: 1 }} />

        <div style={{
          display: 'flex',
          padding: 2,
          background: 'rgba(255,255,255,0.04)',
          border: '0.5px solid rgba(255,255,255,0.06)',
          borderRadius: 5,
        }}>
          {['Core', 'Eng', 'PM'].map((g, i) => (
            <button key={g} style={{
              background: i === 0 ? 'rgba(255,138,91,0.22)' : 'transparent',
              border: 'none',
              color: i === 0 ? BD_ACCENT : 'rgba(255,255,255,0.55)',
              fontSize: 10, fontWeight: 600, padding: '3px 8px',
              borderRadius: 3, cursor: 'pointer',
            }}>{g}</button>
          ))}
        </div>

        <button onClick={() => setShowSettings(true)} aria-label="Settings" style={{
          background: 'rgba(255,255,255,0.04)',
          border: '0.5px solid rgba(255,255,255,0.08)',
          color: 'rgba(255,255,255,0.7)',
          fontSize: 12, fontWeight: 500,
          width: 24, height: 24, borderRadius: 5, cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          padding: 0,
        }}>⚙</button>
      </div>

      <div style={{ padding: '10px 12px 6px' }}>
        <BD_Map hostHour={hostHour} hostDate={hostDate} team={activeTeam} mapStyle={mapStyle} />
      </div>

      <div style={{ padding: '4px 12px 8px' }}>
        <div style={{
          display: 'flex', justifyContent: 'space-between',
          fontSize: 9, color: 'rgba(255,255,255,0.35)', marginBottom: 3,
          fontVariantNumeric: 'tabular-nums', letterSpacing: 0.3,
        }}>
          {[0, 6, 12, 18, 24].map(h => (
            <span key={h}>{h === 24 ? '12a' : formatHourShort(h)}</span>
          ))}
        </div>
        <div style={{ position: 'relative', height: 22 }}>
          <div style={{
            position: 'absolute', top: 8, left: 0, right: 0, height: 6,
            background: 'rgba(255,255,255,0.06)', borderRadius: 3,
          }}>
            {windows.map((w, i) => (
              <div key={i} style={{
                position: 'absolute', top: 0, bottom: 0,
                left: `${(w.start / 24) * 100}%`,
                width: `${((w.end - w.start) / 24) * 100}%`,
                background: w.minScore >= 0.95 ? `${BD_GREEN}80` : `${BD_AMBER}66`,
                borderRadius: 3,
              }} />
            ))}
          </div>
          <input type="range" min={0} max={23.5} step={0.5} value={hostHour}
            onChange={(e) => setHostHour(parseFloat(e.target.value))}
            style={{ position: 'absolute', inset: 0, width: '100%', opacity: 0, cursor: 'grab', margin: 0 }}
          />
          <div style={{
            position: 'absolute', top: 1,
            left: `calc(${(hostHour / 24) * 100}% - 9px)`,
            width: 18, height: 18, borderRadius: '50%',
            background: BD_ACCENT,
            boxShadow: `0 2px 8px ${BD_ACCENT}80, 0 0 0 0.5px rgba(0,0,0,0.5)`,
            pointerEvents: 'none',
          }} />
        </div>
      </div>

      <div style={{
        background: 'rgba(0,0,0,0.2)',
        borderTop: '0.5px solid rgba(255,255,255,0.06)',
      }}>
        {ordered.map((p, idx) => {
          const isSel = selected.has(p.id);
          const prevSel = idx > 0 ? selected.has(ordered[idx - 1].id) : true;
          const showDivider = idx > 0 && prevSel && !isSel;
          return (
            <React.Fragment key={p.id}>
              {showDivider && (
                <div style={{
                  padding: '6px 12px 4px',
                  fontSize: 8.5, fontWeight: 700, letterSpacing: 0.8,
                  color: 'rgba(255,255,255,0.3)',
                  background: 'rgba(0,0,0,0.25)',
                  borderTop: '0.5px solid rgba(255,255,255,0.06)',
                  borderBottom: '0.5px solid rgba(255,255,255,0.04)',
                }}>
                  HIDDEN · CLICK AVATAR TO INCLUDE
                </div>
              )}
              <BD_PersonRow p={p}
                hostHour={hostHour} hostDate={hostDate}
                onPickTime={setHostHour}
                selected={isSel}
                onToggle={toggle}
              />
            </React.Fragment>
          );
        })}
      </div>

      <div style={{
        padding: '9px 12px 10px',
        background: 'rgba(0,0,0,0.3)',
        borderTop: '0.5px solid rgba(255,255,255,0.08)',
        display: 'flex', alignItems: 'center', gap: 10,
      }}>
        <div style={{
          fontSize: 9, color: 'rgba(255,255,255,0.45)',
          fontWeight: 700, letterSpacing: 0.8,
          whiteSpace: 'nowrap',
        }}>
          BEST SLOTS
        </div>
        <div style={{ display: 'flex', gap: 5, flex: 1, flexWrap: 'wrap' }}>
          {windows.slice(0, 4).map((w, i) => {
            const isGreat = w.minScore >= 0.95;
            const dur = w.end - w.start;
            return (
              <button key={i}
                onClick={() => setHostHour(w.start + dur / 2)}
                style={{
                  display: 'flex', alignItems: 'center', gap: 5,
                  padding: '3px 8px',
                  background: isGreat ? `${BD_GREEN}14` : `${BD_AMBER}10`,
                  border: `0.5px solid ${isGreat ? `${BD_GREEN}55` : `${BD_AMBER}40`}`,
                  borderRadius: 4, cursor: 'pointer',
                  color: isGreat ? '#a7eb7e' : '#e8b96b',
                  fontSize: 10.5, fontWeight: 600, fontVariantNumeric: 'tabular-nums',
                  whiteSpace: 'nowrap',
                }}>
                <div style={{
                  width: 4, height: 4, borderRadius: '50%',
                  background: isGreat ? BD_GREEN : BD_AMBER,
                }} />
                {formatHour(w.start)}–{formatHour(w.end)}
                <span style={{
                  opacity: 0.55, fontSize: 9, fontWeight: 500,
                  marginLeft: 1,
                }}>{dur}h</span>
              </button>
            );
          })}
        </div>
        <button style={{
          background: 'transparent', border: 'none',
          color: 'rgba(255,255,255,0.6)', fontSize: 10.5, fontWeight: 500,
          cursor: 'pointer', padding: '2px 0', whiteSpace: 'nowrap',
        }}>Copy invite ↗</button>
      </div>

      {showSettings && (
        <BD_Settings team={team} setTeam={setTeam} onClose={() => setShowSettings(false)} />
      )}
    </div>
  );
}

window.DirBD = DirBD;

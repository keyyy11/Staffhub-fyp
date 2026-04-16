/** Fixed order — must match staffController default week. */
const WEEK_DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/** Masa anggaran untuk shift (boleh diselaraskan di satu tempat). */
const SHIFT_WINDOWS = {
  morning: { isWorkingDay: true, workStart: '08:00', workEnd: '14:00' },
  afternoon: { isWorkingDay: true, workStart: '14:00', workEnd: '22:00' },
  off: { isWorkingDay: false, workStart: '09:00', workEnd: '18:00' },
};

const SHIFT_LABEL_MS = {
  morning: 'Shift pagi',
  afternoon: 'Shift petang',
  off: 'Hari cuti',
};

function coerceWorkingDay(value, fallback) {
  if (value === undefined || value === null) return fallback;
  return value === true || value === 'true' || value === 1;
}

function inferShiftTypeFromLegacy(d, dayName) {
  const st = String(d.shiftType || '').toLowerCase();
  if (st === 'morning' || st === 'afternoon' || st === 'off') return st;
  const wdOff = dayName === 'Saturday' || dayName === 'Sunday';
  let working = d.isWorkingDay;
  if (working === undefined || working === null) working = !wdOff;
  else working = coerceWorkingDay(working, !wdOff);
  if (!working) return 'off';
  const ws = String(d.workStart != null ? d.workStart : '09:00');
  const h = parseInt(ws.split(':')[0], 10);
  if (Number.isNaN(h)) return 'morning';
  return h < 13 ? 'morning' : 'afternoon';
}

/**
 * Simpan 7 hari dengan shiftType (morning|afternoon|off) + masa konsisten.
 */
function normalizeScheduleDays(days) {
  if (!Array.isArray(days) || days.length === 0) {
    return WEEK_DAYS.map((dayName) => {
      const off = dayName === 'Saturday' || dayName === 'Sunday';
      const st = off ? 'off' : 'morning';
      const w = SHIFT_WINDOWS[st];
      return {
        day: dayName,
        shiftType: st,
        isWorkingDay: w.isWorkingDay,
        workStart: w.workStart,
        workEnd: w.workEnd,
      };
    });
  }
  const byDay = Object.fromEntries(
    days.filter((d) => d && d.day).map((d) => [String(d.day), d]),
  );
  return WEEK_DAYS.map((dayName) => {
    const d = byDay[dayName];
    if (!d) {
      const off = dayName === 'Saturday' || dayName === 'Sunday';
      const st = off ? 'off' : 'morning';
      const w = SHIFT_WINDOWS[st];
      return {
        day: dayName,
        shiftType: st,
        isWorkingDay: w.isWorkingDay,
        workStart: w.workStart,
        workEnd: w.workEnd,
      };
    }
    const st = inferShiftTypeFromLegacy(d, dayName);
    const w = SHIFT_WINDOWS[st];
    return {
      day: dayName,
      shiftType: st,
      isWorkingDay: w.isWorkingDay,
      workStart: w.workStart,
      workEnd: w.workEnd,
    };
  });
}

function deriveShiftTypeForApiRow(o, def) {
  const dayName = (o && o.day) || def.day;
  if (!o) return inferShiftTypeFromLegacy({ isWorkingDay: def.isWorkingDay, workStart: def.workStart }, dayName);
  const st = String(o.shiftType || '').toLowerCase();
  if (st === 'morning' || st === 'afternoon' || st === 'off') return st;
  return inferShiftTypeFromLegacy(o, dayName);
}

function isoDateToDayName(isoDateStr) {
  const parts = String(isoDateStr).trim().split('-');
  if (parts.length !== 3) return 'Monday';
  const y = parseInt(parts[0], 10);
  const m = parseInt(parts[1], 10);
  const d = parseInt(parts[2], 10);
  if (Number.isNaN(y) || Number.isNaN(m) || Number.isNaN(d)) return 'Monday';
  const dt = new Date(y, m - 1, d);
  const wd = dt.getDay();
  const map = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  return map[wd];
}

/**
 * Simpan override tarikh (YYYY-MM-DD) dengan shift konsisten.
 */
function normalizeDateEntries(entries) {
  if (!Array.isArray(entries)) return [];
  const byDate = new Map();
  for (const e of entries) {
    if (!e || !e.date) continue;
    const date = String(e.date).trim();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) continue;
    const dayName = isoDateToDayName(date);
    const st = inferShiftTypeFromLegacy(
      {
        shiftType: e.shiftType,
        isWorkingDay: e.isWorkingDay,
        workStart: e.workStart,
      },
      dayName,
    );
    const w = SHIFT_WINDOWS[st];
    byDate.set(date, {
      date,
      shiftType: st,
      isWorkingDay: w.isWorkingDay,
      workStart: w.workStart,
      workEnd: w.workEnd,
    });
  }
  return Array.from(byDate.values()).sort((a, b) => a.date.localeCompare(b.date));
}

/**
 * Tarikh tertentu: override [dateEntries] jika ada, jika tidak guna jadual mingguan [days], akhirnya lalai syarikat.
 */
function resolveShiftForDate(isoDateStr, customDoc, defaultDays) {
  const dayName = isoDateToDayName(isoDateStr);
  const entries = (customDoc && customDoc.dateEntries) || [];
  const hit = entries.find((e) => e && e.date === isoDateStr);
  if (hit) {
    const st = String(hit.shiftType || '').toLowerCase();
    const st2 =
      st === 'morning' || st === 'afternoon' || st === 'off'
        ? st
        : inferShiftTypeFromLegacy(hit, dayName);
    const w = SHIFT_WINDOWS[st2];
    return {
      date: isoDateStr,
      day: dayName,
      shiftType: st2,
      shiftLabel: SHIFT_LABEL_MS[st2],
      isWorkingDay: w.isWorkingDay,
      workStart: w.workStart,
      workEnd: w.workEnd,
      source: 'date',
    };
  }
  const daysArr = (customDoc && customDoc.days) || [];
  const byDay = Object.fromEntries(daysArr.filter((x) => x && x.day).map((d) => [d.day, d]));
  const o = byDay[dayName];
  const def = defaultDays.find((d) => d.day === dayName) || {
    day: dayName,
    isWorkingDay: true,
    workStart: '09:00',
    workEnd: '18:00',
  };
  const st = deriveShiftTypeForApiRow(o, def);
  const w = SHIFT_WINDOWS[st];
  return {
    date: isoDateStr,
    day: dayName,
    shiftType: st,
    shiftLabel: SHIFT_LABEL_MS[st],
    isWorkingDay: w.isWorkingDay,
    workStart: w.workStart,
    workEnd: w.workEnd,
    source: o ? 'weekly' : 'default',
  };
}

/** Satu bulan penuh (array ikut hari 1..last). month = 1–12 */
function buildCalendarMonth(year, month, customDoc, defaultDays) {
  const last = new Date(year, month, 0).getDate();
  const out = [];
  for (let d = 1; d <= last; d++) {
    const iso = `${year}-${String(month).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
    out.push(resolveShiftForDate(iso, customDoc || {}, defaultDays));
  }
  return out;
}

module.exports = {
  WEEK_DAYS,
  SHIFT_WINDOWS,
  SHIFT_LABEL_MS,
  normalizeScheduleDays,
  normalizeDateEntries,
  coerceWorkingDay,
  deriveShiftTypeForApiRow,
  inferShiftTypeFromLegacy,
  isoDateToDayName,
  resolveShiftForDate,
  buildCalendarMonth,
};

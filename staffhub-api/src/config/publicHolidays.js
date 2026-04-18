/**
 * Cuti umum untuk petanda kalendar + nota bayaran (contoh 2x sejam jika bekerja).
 * Tetapan penuh: PUBLIC_HOLIDAYS_JSON dalam .env (array { date, name?, hourlyPayMultiplier? }).
 *
 * Senarai lalai: tarikh cuti persekutuan 2026 (anggapan rasmi; semak tahunan).
 */

const DEFAULT_MULTIPLIER =
  parseFloat(String(process.env.PUBLIC_HOLIDAY_HOURLY_MULTIPLIER || '2'), 10) || 2;

/** Cuti persekutuan — tarikh ISO — nama ringkas BM */
const DEFAULT_MY_FEDERAL_2026 = [
  { date: '2026-02-17', name: 'Tahun Baru Cina' },
  { date: '2026-02-18', name: 'Tahun Baru Cina (hari 2)' },
  { date: '2026-03-20', name: 'Hari Raya Aidilfitri' },
  { date: '2026-03-21', name: 'Hari Raya Aidilfitri (hari 2)' },
  { date: '2026-05-01', name: 'Hari Pekerja' },
  { date: '2026-05-27', name: 'Hari Raya Haji' },
  { date: '2026-05-28', name: 'Hari Raya Haji (hari 2)' },
  { date: '2026-05-31', name: 'Wesak' },
  { date: '2026-06-01', name: 'Hari Keputeraan YDPA' },
  { date: '2026-06-17', name: 'Awal Muharram' },
  { date: '2026-08-25', name: 'Maulidur Rasul' },
  { date: '2026-08-31', name: 'Hari Kebangsaan' },
  { date: '2026-09-16', name: 'Hari Malaysia' },
  { date: '2026-11-08', name: 'Deepavali' },
  { date: '2026-12-25', name: 'Krismas' },
];

const PAY_NOTE_MS =
  'Hari bertanda cuti umum: jika anda bekerja pada tarikh tersebut, bayaran sejam biasanya diagih berganda (contoh 2×) mengikut dasar syarikat / HR.';

function loadHolidayMap() {
  const map = new Map();
  let list = [];

  const raw = process.env.PUBLIC_HOLIDAYS_JSON;
  if (raw && String(raw).trim()) {
    try {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed) && parsed.length > 0) list = parsed;
    } catch (e) {
      // eslint-disable-next-line no-console
      console.warn('[publicHolidays] PUBLIC_HOLIDAYS_JSON invalid:', e.message);
    }
  }
  if (list.length === 0) list = DEFAULT_MY_FEDERAL_2026;

  for (const h of list) {
    if (!h || !h.date) continue;
    const date = String(h.date).trim();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) continue;
    const mult =
      typeof h.hourlyPayMultiplier === 'number' && Number.isFinite(h.hourlyPayMultiplier)
        ? h.hourlyPayMultiplier
        : DEFAULT_MULTIPLIER;
    map.set(date, {
      name: h.name || 'Cuti umum',
      hourlyPayMultiplier: mult,
    });
  }
  return map;
}

let _cachedMap = null;
function getHolidayMap() {
  if (!_cachedMap) _cachedMap = loadHolidayMap();
  return _cachedMap;
}

function getPublicHolidayForDate(isoDateStr) {
  return getHolidayMap().get(String(isoDateStr).trim()) || null;
}

/**
 * @param {Array<Object>} days - output `buildCalendarMonth` (mempunyai `date`)
 */
function enrichCalendarDays(days) {
  if (!Array.isArray(days)) return [];
  return days.map((d) => {
    if (!d || !d.date) {
      return {
        ...d,
        isPublicHoliday: false,
        publicHolidayName: null,
        publicHolidayHourlyMultiplier: null,
      };
    }
    const ph = getPublicHolidayForDate(d.date);
    if (!ph) {
      return {
        ...d,
        isPublicHoliday: false,
        publicHolidayName: null,
        publicHolidayHourlyMultiplier: null,
      };
    }
    return {
      ...d,
      isPublicHoliday: true,
      publicHolidayName: ph.name,
      publicHolidayHourlyMultiplier: ph.hourlyPayMultiplier,
    };
  });
}

module.exports = {
  DEFAULT_MULTIPLIER,
  enrichCalendarDays,
  getPublicHolidayForDate,
  PAY_NOTE_MS,
};

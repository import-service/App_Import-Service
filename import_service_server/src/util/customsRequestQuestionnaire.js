const MAX_LIST_ITEMS = 50;
const NAME_MAX = 255;
const YEAR_MIN = 1900;
const YEAR_MAX = 2100;

function parseDateOnly(raw) {
  const s = String(raw ?? '').trim().slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return null;
  const [y, m, d] = s.split('-').map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d));
  if (dt.getUTCFullYear() !== y || dt.getUTCMonth() !== m - 1 || dt.getUTCDate() !== d) {
    return null;
  }
  return s;
}

function coerceArray(raw) {
  if (raw == null || raw === '') return [];
  if (Buffer.isBuffer(raw)) {
    raw = raw.toString('utf8');
  }
  if (Array.isArray(raw)) return raw;
  if (typeof raw === 'string') {
    try {
      const parsed = JSON.parse(raw);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
  return [];
}

function normalizePreviousImportDates(raw) {
  const out = [];
  const seen = new Set();
  for (const item of coerceArray(raw).slice(0, MAX_LIST_ITEMS)) {
    const value =
      item && typeof item === 'object' ? parseDateOnly(item.date ?? item.value) : parseDateOnly(item);
    if (!value || seen.has(value)) continue;
    seen.add(value);
    out.push(value);
  }
  out.sort();
  return out;
}

function normalizeYear(raw) {
  const n = typeof raw === 'number' ? raw : Number(String(raw ?? '').replace(/\D/g, ''));
  if (!Number.isInteger(n) || n < YEAR_MIN || n > YEAR_MAX) return null;
  return n;
}

function normalizeOwnedVehicles(raw) {
  const out = [];
  for (const item of coerceArray(raw).slice(0, MAX_LIST_ITEMS)) {
    if (!item || typeof item !== 'object') continue;
    const name = String(item.name ?? item.title ?? '').trim().slice(0, NAME_MAX);
    const year = normalizeYear(item.year);
    if (!name || year == null) continue;
    out.push({ name, year });
  }
  return out;
}

function questionnaireFromBody(body) {
  const src = body && typeof body === 'object' ? body : {};
  const hasDatesKey = src.previousImportDates !== undefined;
  const hasCarsKey = src.ownedVehicles !== undefined;
  const previousImportDates = hasDatesKey
    ? normalizePreviousImportDates(src.previousImportDates)
    : [];
  const ownedVehicles = hasCarsKey ? normalizeOwnedVehicles(src.ownedVehicles) : [];
  return {
    previousImportDates,
    ownedVehicles,
    importedLast12Months: hasDatesKey ? previousImportDates.length > 0 : Boolean(src.importedLast12Months),
    ownsOtherCars: hasCarsKey ? ownedVehicles.length > 0 : Boolean(src.ownsOtherCars),
  };
}

function questionnaireFromRow(row) {
  const previousImportDates = normalizePreviousImportDates(row?.previous_import_dates);
  const ownedVehicles = normalizeOwnedVehicles(row?.owned_vehicles);
  return {
    previousImportDates,
    ownedVehicles,
    importedLast12Months: previousImportDates.length > 0 || Boolean(row?.imported_last_12_months),
    ownsOtherCars: ownedVehicles.length > 0 || Boolean(row?.owns_other_cars),
  };
}

function questionnaireToDbValues(q) {
  return {
    previousImportDatesJson: JSON.stringify(q.previousImportDates),
    ownedVehiclesJson: JSON.stringify(q.ownedVehicles),
    importedLast12Months: q.importedLast12Months ? 1 : 0,
    ownsOtherCars: q.ownsOtherCars ? 1 : 0,
  };
}

module.exports = {
  normalizePreviousImportDates,
  normalizeOwnedVehicles,
  questionnaireFromBody,
  questionnaireFromRow,
  questionnaireToDbValues,
};

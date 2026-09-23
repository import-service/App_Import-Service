const ALLOWED_ORG_ROLES = Object.freeze([
  'user',
  'svh_manager',
  'declarant_manager',
  'admin',
]);

/** Приоритет primary role для JWT / старых клиентов. */
const PRIMARY_ROLE_PRIORITY = Object.freeze([
  'svh_manager',
  'declarant_manager',
  'admin',
  'user',
]);

function normalizeRoleCode(raw) {
  const s = String(raw ?? '')
    .trim()
    .toLowerCase();
  if (s === 'svh' || s === 'svh-manager') return 'svh_manager';
  if (s === 'declarant' || s === 'declarant-manager') return 'declarant_manager';
  return s;
}

function parseRolesJson(raw) {
  if (raw == null || raw === '') return [];
  let value = raw;
  if (Buffer.isBuffer(value)) value = value.toString('utf8');
  if (typeof value === 'string') {
    try {
      value = JSON.parse(value);
    } catch {
      return [];
    }
  }
  if (!Array.isArray(value)) return [];
  const out = [];
  const seen = new Set();
  for (const item of value) {
    const code = normalizeRoleCode(item);
    if (!ALLOWED_ORG_ROLES.includes(code) || seen.has(code)) continue;
    seen.add(code);
    out.push(code);
  }
  return out;
}

function rolesFromRow(row) {
  const fromJson = parseRolesJson(row?.roles);
  if (fromJson.length) return fromJson;
  const primary = normalizeRoleCode(row?.role);
  if (ALLOWED_ORG_ROLES.includes(primary)) return [primary];
  return ['user'];
}

function pickPrimaryRole(roles) {
  const list = Array.isArray(roles) ? roles : [];
  for (const code of PRIMARY_ROLE_PRIORITY) {
    if (list.includes(code)) return code;
  }
  return list[0] || 'user';
}

function normalizeRolesInput(rawRoles, { required = true } = {}) {
  if (rawRoles === undefined || rawRoles === null) {
    if (required) {
      throw new Error('VALIDATION_ERROR: roles обязателен (массив)');
    }
    return undefined;
  }
  if (!Array.isArray(rawRoles)) {
    throw new Error('VALIDATION_ERROR: roles должен быть массивом');
  }
  const out = [];
  const seen = new Set();
  for (const item of rawRoles) {
    const code = normalizeRoleCode(item);
    if (!ALLOWED_ORG_ROLES.includes(code)) {
      throw new Error(`VALIDATION_ERROR: неизвестная роль ${item}`);
    }
    if (seen.has(code)) continue;
    seen.add(code);
    out.push(code);
  }
  if (!out.length) {
    throw new Error('VALIDATION_ERROR: нужна хотя бы одна роль');
  }
  return out;
}

function hasRole(rolesOrRow, code) {
  const roles = Array.isArray(rolesOrRow) ? rolesOrRow : rolesFromRow(rolesOrRow);
  return roles.includes(normalizeRoleCode(code));
}

module.exports = {
  ALLOWED_ORG_ROLES,
  PRIMARY_ROLE_PRIORITY,
  normalizeRoleCode,
  parseRolesJson,
  rolesFromRow,
  pickPrimaryRole,
  normalizeRolesInput,
  hasRole,
};

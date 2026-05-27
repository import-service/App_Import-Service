function toIso(mysqlDate) {
  if (!mysqlDate) return null;
  try {
    return new Date(mysqlDate).toISOString();
  } catch {
    return null;
  }
}

function toOrganizationDto(row) {
  return {
    id: row.id,
    id_1c: row.id_1c,
    login: row.login,
    role: row.role,
    orgType: row.org_type,
    companyName: row.company_name,
    inn: row.inn,
    phone: row.phone,
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
    deletedAt: toIso(row.deleted_at),
  };
}

module.exports = { toOrganizationDto };

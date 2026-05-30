/// Postgres-specific helpers.
String pgQuoteIdent(String identifier) =>
    '"${identifier.replaceAll('"', '""')}"';

/// Postgres parameter placeholder: $1, $2, ...
String pgPlaceholder(int index) => '\$$index';

/// Quote a possibly-schema-qualified name like 'public.users'.
String pgQuoteQualified(String? schema, String name) {
  if (schema == null || schema.isEmpty) return pgQuoteIdent(name);
  return '${pgQuoteIdent(schema)}.${pgQuoteIdent(name)}';
}

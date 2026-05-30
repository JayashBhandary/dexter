/// MySQL identifier quoting uses backticks.
String myQuoteIdent(String identifier) =>
    '`${identifier.replaceAll('`', '``')}`';

/// MySQL prepared statements use positional `?` placeholders.
String myPlaceholder(int index) => '?';

String myQuoteQualified(String? schema, String name) {
  if (schema == null || schema.isEmpty) return myQuoteIdent(name);
  return '${myQuoteIdent(schema)}.${myQuoteIdent(name)}';
}

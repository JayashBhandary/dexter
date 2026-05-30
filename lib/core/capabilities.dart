enum Capability {
  rawQuery,
  write,
  schemaRead,
  schemaMutate,
  objectStorage,
  fileBrowse,
  endpointInvoke,
  transactions,
}

enum DataSourceKind {
  sqlite,
  postgres,
  mysql,
  firestore,
  mongo,
  s3,
  rest,
  graphql;

  String get label => switch (this) {
        sqlite => 'SQLite',
        postgres => 'PostgreSQL',
        mysql => 'MySQL',
        firestore => 'Firestore',
        mongo => 'MongoDB',
        s3 => 'S3 / MinIO',
        rest => 'REST API',
        graphql => 'GraphQL API',
      };
}

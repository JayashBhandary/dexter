class DexterError implements Exception {
  const DexterError(this.message, {this.cause, this.stack});
  final String message;
  final Object? cause;
  final StackTrace? stack;

  @override
  String toString() => 'DexterError: $message${cause != null ? ' ($cause)' : ''}';
}

class ConnectError extends DexterError {
  const ConnectError(super.message, {super.cause, super.stack});
}

class QueryError extends DexterError {
  const QueryError(super.message, {super.cause, super.stack});
}

class CapabilityError extends DexterError {
  const CapabilityError(super.message);
}

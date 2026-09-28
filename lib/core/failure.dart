/// Why a piece of work failed. Used for logging and for choosing a user message.
enum FailureKind { network, timeout, server, parsing, notFound, unknown }

/// A failure that has already been turned into something displayable.
///
/// The data layer never lets an exception escape, so every ViewModel can rely on
/// receiving a [Failure] instead of having to wrap calls in try/catch.
class Failure {
  const Failure(this.kind, this.message, {this.cause, this.statusCode});

  const Failure.network([String message = 'No internet connection.'])
    : this(FailureKind.network, message);

  const Failure.timeout([String message = 'The request timed out.'])
    : this(FailureKind.timeout, message);

  const Failure.parsing([String message = 'Unexpected response from the server.'])
    : this(FailureKind.parsing, message);

  const Failure.unknown([String message = 'Something went wrong.'])
    : this(FailureKind.unknown, message);

  final FailureKind kind;
  final String message;
  final Object? cause;
  final int? statusCode;

  /// Whether retrying the same request could plausibly succeed.
  bool get isRetryable =>
      kind == FailureKind.network ||
      kind == FailureKind.timeout ||
      kind == FailureKind.server;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' (HTTP $statusCode)';
    return '${kind.name}: $message$code';
  }
}

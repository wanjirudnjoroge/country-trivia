import 'failure.dart';

export 'failure.dart';

/// The outcome of a fallible operation: either a [T] value or a [Failure].
///
/// Exhaustive `switch` over this type means the compiler forces every caller to
/// handle the error path.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// The value, or `null` when this is an [Err].
  T? get valueOrNull => switch (this) {
    Ok<T>(:final T value) => value,
    Err<T>() => null,
  };

  /// The failure, or `null` when this is an [Ok].
  Failure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final Failure failure) => failure,
  };

  /// Transforms a success value, leaving a failure untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final T value) => Ok<R>(transform(value)),
    Err<T>(:final Failure failure) => Err<R>(failure),
  };

  /// Collapses both branches into a single value.
  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) =>
      switch (this) {
        Ok<T>(:final T value) => onOk(value),
        Err<T>(:final Failure failure) => onErr(failure),
      };
}

/// A successful [Result] carrying a value.
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  String toString() => 'Ok($value)';
}

/// A failed [Result] carrying a [Failure].
final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;

  @override
  String toString() => 'Err($failure)';
}

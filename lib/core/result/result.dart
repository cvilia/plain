/// Result / Failure. See 05-B5.
library;

sealed class Failure {
  const Failure(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'Failure($code, $message)';
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.code, super.message);
}

final class ConflictFailure extends Failure {
  const ConflictFailure(super.code, super.message);
}

final class StorageFailure extends Failure {
  const StorageFailure(super.code, super.message, {this.isRetryable = false});
  final bool isRetryable;
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.code, super.message);
}

sealed class Result<T> {
  const Result();
  bool get isSuccess;
  bool get isFailure;
  T? get successOrNull;
  Failure? get failureOrNull;
  R when<R>({required R Function(T value) success, required R Function(Failure failure) failure});
  T get requireValue;
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
  @override
  bool get isSuccess => true;
  @override
  bool get isFailure => false;
  @override
  T? get successOrNull => value;
  @override
  Failure? get failureOrNull => null;
  @override
  R when<R>({required R Function(T value) success, required R Function(Failure failure) failure}) => success(value);
  @override
  T get requireValue => value;
}

final class Fail<T> extends Result<T> {
  const Fail(this.failure);
  final Failure failure;
  @override
  bool get isSuccess => false;
  @override
  bool get isFailure => true;
  @override
  T? get successOrNull => null;
  @override
  Failure? get failureOrNull => failure;
  @override
  R when<R>({required R Function(T value) success, required R Function(Failure failure) failure}) => failure(this.failure);
  @override
  T get requireValue => throw StateError('Result is failure: $failure');
}

Result<T> ok<T>(T value) => Success(value);
Result<T> err<T>(Failure failure) => Fail(failure);

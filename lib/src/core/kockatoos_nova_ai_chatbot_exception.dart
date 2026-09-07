import 'package:meta/meta.dart';

@immutable
abstract class NovaException implements Exception {
  final String message;
  const NovaException(this.message);

  @override
  String toString() => 'NovaException: $message';
}

class NovaNotInitializedException extends NovaException {
  const NovaNotInitializedException(super.message);
}

class NovaAuthException extends NovaException {
  const NovaAuthException(super.message);
}

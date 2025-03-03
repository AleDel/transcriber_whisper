// app_exceptions.dart
class AppException implements Exception {
  final String message;
  final String? details;

  AppException(this.message, {this.details});

  @override
  String toString() => 'AppException: $message ${details != null ? "($details)" : ""}';
}

class NetworkException extends AppException {
  NetworkException(String message, {String? details}) : super(message, details: details);
}

class ServerException extends AppException {
  ServerException(String message, {String? details}) : super(message, details: details);
}

class FileException extends AppException {
  FileException(String message, {String? details}) : super(message, details: details);
}

class UnknownException extends AppException {
  UnknownException(String message, {String? details}) : super(message, details: details);
}
class ServerNotAvailableException extends NetworkException {
  ServerNotAvailableException(String message, {String? details}) : super(message, details: details);
}
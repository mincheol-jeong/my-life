import 'dart:developer' as developer;

abstract final class AppLogger {
  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: 'MY_LIFE',
      level: 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

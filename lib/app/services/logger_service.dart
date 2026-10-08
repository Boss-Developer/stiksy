import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// A developer-friendly logging console for the LayerX app.
///
/// Wraps the `logger` package with a colorful, emoji-tagged printer and adds
/// helpers for HTTP request/response logs, pretty JSON, section dividers and
/// execution timing. All output is gated behind [kDebugMode], so nothing is
/// printed in release builds.
class LoggerService {
  LoggerService._();

  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  static final Logger _logger = Logger(
    filter: ProductionFilter(),
    level: kDebugMode ? Level.trace : Level.warning,
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 6,
      lineLength: 100,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      levelEmojis: {
        Level.trace: '🔍',
        Level.debug: '🐛',
        Level.info: '💡',
        Level.warning: '⚠️',
        Level.error: '❌',
        Level.fatal: '💀',
      },
    ),
  );

  // ---- Core levels (backward compatible) --------------------------------

  static void d(dynamic message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) _logger.d(message, error: error, stackTrace: stackTrace);
  }

  static void i(dynamic message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) _logger.i(message, error: error, stackTrace: stackTrace);
  }

  static void w(dynamic message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) _logger.w(message, error: error, stackTrace: stackTrace);
  }

  static void e(dynamic message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) _logger.e(message, error: error, stackTrace: stackTrace);
  }

  // ---- Developer console helpers ----------------------------------------

  /// A success line.
  static void s(dynamic message) {
    if (kDebugMode) _logger.i('✅ $message');
  }

  /// A labelled section divider.
  static void divider([String title = '']) {
    if (!kDebugMode) return;
    _logger.i(
      title.isEmpty
          ? '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
          : '━━━━━ $title ━━━━━',
    );
  }

  /// A boot banner — call once from `main()` to announce the app in the console.
  static void banner({String name = 'LayerX', String? version, String? env}) {
    if (!kDebugMode) return;
    final tags = <String>[
      if (version != null) 'v$version',
      if (env != null) env.toUpperCase(),
    ];
    final subtitle = tags.isEmpty ? '' : '  •  ${tags.join('  •  ')}';
    _logger.i(
      '🧱  $name$subtitle\n'
      '✨  Clean architecture · GetX · zero boilerplate\n'
      '🟢  Console ready — happy shipping!',
    );
  }

  /// A warning line with a lightbulb — great for actionable hints.
  static void hint(dynamic message) {
    if (kDebugMode) _logger.w('💡 $message');
  }

  /// Pretty-prints any JSON-encodable value.
  static void json(Object? data, {String label = 'JSON'}) {
    if (kDebugMode) _logger.i('🧾 $label\n${_safeJson(data)}');
  }

  /// Logs an outgoing HTTP request.
  static void request(String method, String url, {Object? body}) {
    if (!kDebugMode) return;
    final buffer = StringBuffer('📤 $method  $url');
    if (body != null) buffer.write('\n📦 Body: ${_safeJson(body)}');
    _logger.d(buffer.toString());
  }

  /// Logs an incoming HTTP response.
  static void response(
    int statusCode,
    String url, {
    Object? body,
    Duration? elapsed,
  }) {
    if (!kDebugMode) return;
    final ok = statusCode >= 200 && statusCode < 300;
    final time = elapsed == null ? '' : ' • ${elapsed.inMilliseconds}ms';
    final buffer = StringBuffer('${ok ? '✅' : '❌'} ← $statusCode  $url$time');
    if (body != null) buffer.write('\n📦 ${_safeJson(body)}');
    ok ? _logger.i(buffer.toString()) : _logger.e(buffer.toString());
  }

  /// Runs [action], logging how long it took (and any failure).
  static Future<T> timed<T>(String label, Future<T> Function() action) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await action();
      stopwatch.stop();
      if (kDebugMode) {
        _logger.i('⏱️ $label took ${stopwatch.elapsedMilliseconds}ms');
      }
      return result;
    } catch (error, stackTrace) {
      stopwatch.stop();
      if (kDebugMode) {
        _logger.e(
          '⏱️ $label failed after ${stopwatch.elapsedMilliseconds}ms',
          error: error,
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }
  }

  static String _safeJson(Object? data) {
    try {
      return _encoder.convert(data);
    } catch (_) {
      return '$data';
    }
  }
}

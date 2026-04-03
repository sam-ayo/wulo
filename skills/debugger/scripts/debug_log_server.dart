import 'dart:convert';
import 'dart:io';

/// A simple HTTP server that receives debug logs from the Flutter app
/// and prints them to the terminal with color formatting.
///
/// Usage: dart run tool/debug_log_server.dart
///
/// The Flutter app sends POST requests to http://127.0.0.1:8389/log
/// with JSON body: { timestamp, tag, message, data? }
void main() async {
  const port = 8389;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);

  _printColored('\n  Debug Log Server listening on :$port\n', _cyan);
  _printColored('  Waiting for logs from the Flutter app...\n\n', _dim);

  await for (final request in server) {
    if (request.method == 'POST' && request.uri.path == '/log') {
      await _handleLog(request);
    } else if (request.method == 'GET' && request.uri.path == '/health') {
      request.response
        ..statusCode = HttpStatus.ok
        ..write('ok')
        ..close();
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..close();
    }
  }
}

Future<void> _handleLog(HttpRequest request) async {
  try {
    final body = await utf8.decoder.bind(request).join();
    final log = jsonDecode(body) as Map<String, dynamic>;

    final timestamp = log['timestamp'] as String? ?? '';
    final tag = log['tag'] as String? ?? 'unknown';
    final message = log['message'] as String? ?? '';
    final data = log['data'];

    // Format time from ISO string
    String time;
    try {
      final dt = DateTime.parse(timestamp);
      time = '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}:'
          '${dt.second.toString().padLeft(2, '0')}.'
          '${dt.millisecond.toString().padLeft(3, '0')}';
    } catch (_) {
      time = timestamp;
    }

    // Color-code by tag for easy scanning
    final color = _tagColor(tag);
    stdout.write('$_dim$time$_reset ');
    _printColored('[$tag]', color);
    stdout.write(' $message\n');

    if (data != null) {
      final pretty = const JsonEncoder.withIndent('  ').convert(data);
      for (final line in pretty.split('\n')) {
        stdout.write('$_dim         $line$_reset\n');
      }
    }

    request.response
      ..statusCode = HttpStatus.ok
      ..write('ok')
      ..close();
  } catch (e) {
    stderr.writeln('Failed to parse log: $e');
    request.response
      ..statusCode = HttpStatus.badRequest
      ..write('invalid log format')
      ..close();
  }
}

// ANSI color codes
const _reset = '\x1B[0m';
const _dim = '\x1B[2m';
const _cyan = '\x1B[36m';
const _green = '\x1B[32m';
const _yellow = '\x1B[33m';
const _magenta = '\x1B[35m';
const _blue = '\x1B[34m';
const _red = '\x1B[31m';

final _tagColors = <String, String>{};
final _colorPool = [_green, _yellow, _magenta, _blue, _cyan, _red];
int _colorIndex = 0;

String _tagColor(String tag) {
  return _tagColors.putIfAbsent(tag, () {
    final color = _colorPool[_colorIndex % _colorPool.length];
    _colorIndex++;
    return color;
  });
}

void _printColored(String text, String color) {
  stdout.write('$color$text$_reset');
}

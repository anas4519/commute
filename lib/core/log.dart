import 'dart:async';
import 'dart:collection';
import 'dart:io';

/// Tiny in-app debug log: ring buffer (500 lines), optionally persisted to a
/// file so it survives restarts. Never pass secrets (API key, headers) here.
class AppLog {
  AppLog._();
  static final AppLog I = AppLog._();
  static const maxLines = 500;

  final _lines = ListQueue<String>();
  final _listeners = <void Function()>{};
  File? _file;
  Timer? _flush;

  List<String> get lines => List.unmodifiable(_lines);

  /// Attach a backing file (call once at startup). Loads previous lines.
  Future<void> attach(File f) async {
    _file = f;
    try {
      if (await f.exists()) {
        final old = await f.readAsLines();
        final merged = [...old, ..._lines];
        _lines
          ..clear()
          ..addAll(merged.skip(merged.length > maxLines ? merged.length - maxLines : 0));
      }
    } catch (_) {}
    _notify();
  }

  static void d(String tag, String msg) => I._add(tag, msg);

  void _add(String tag, String msg) {
    final t = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final ts =
        '${t.month}/${t.day} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}.${t.millisecond.toString().padLeft(3, '0')}';
    _lines.add('$ts [$tag] ${redact(msg)}');
    while (_lines.length > maxLines) {
      _lines.removeFirst();
    }
    _scheduleFlush();
    _notify();
  }

  /// Belt and braces: strip anything that looks like a Google API key.
  static String redact(String s) => s.replaceAll(RegExp(r'AIza[0-9A-Za-z_\-]{20,}'), 'AIza…REDACTED');

  static String trunc(String? s, [int n = 160]) {
    if (s == null) return 'null';
    final one = s.replaceAll(RegExp(r'\s+'), ' ');
    return one.length <= n ? one : '${one.substring(0, n)}…';
  }

  Future<void> clear() async {
    _lines.clear();
    _notify();
    try {
      await _file?.writeAsString('');
    } catch (_) {}
  }

  void _scheduleFlush() {
    if (_file == null) return;
    _flush?.cancel();
    _flush = Timer(const Duration(milliseconds: 500), () async {
      try {
        await _file!.writeAsString('${_lines.join('\n')}\n');
      } catch (_) {}
    });
  }

  void addListener(void Function() l) => _listeners.add(l);
  void removeListener(void Function() l) => _listeners.remove(l);
  void _notify() {
    for (final l in _listeners.toList()) {
      l();
    }
  }
}

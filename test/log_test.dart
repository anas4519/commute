import 'package:commute/core/log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ring buffer caps and redacts', () async {
    await AppLog.I.clear();
    for (var i = 0; i < 600; i++) {
      AppLog.d('t', 'line $i');
    }
    expect(AppLog.I.lines.length, AppLog.maxLines);
    expect(AppLog.I.lines.last, contains('line 599'));
    AppLog.d('t', 'key=AIzaSyA1234567890abcdefghijklmnop');
    expect(AppLog.I.lines.last, isNot(contains('AIzaSyA1234567890')));
    expect(AppLog.trunc('a' * 300, 10), 'aaaaaaaaaa…');
  });
}

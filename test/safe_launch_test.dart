import 'package:flutter_test/flutter_test.dart';
import 'package:zynkup/core/utils/safe_launch.dart';

void main() {
  group('safeHttpUri', () {
    test('accepts http and https links', () {
      expect(safeHttpUri('https://zynkup-app.vercel.app/events/1').toString(),
          'https://zynkup-app.vercel.app/events/1');
      expect(safeHttpUri('  http://example.com  ')!.host, 'example.com');
    });

    test('adds https to scheme-less links', () {
      expect(safeHttpUri('youtube.com/watch?v=abc').toString(),
          'https://youtube.com/watch?v=abc');
    });

    test('rejects dangerous or unsupported schemes', () {
      for (final raw in [
        'javascript:alert(1)',
        'JavaScript:alert(1)',
        'data:text/html,<script>alert(1)</script>',
        'file:///etc/passwd',
        'intent://scan/#Intent;scheme=zxing;end',
        'ftp://example.com/file',
        'zynkup://events/1',
      ]) {
        expect(safeHttpUri(raw), isNull, reason: raw);
      }
    });

    test('rejects empty and host-less values', () {
      expect(safeHttpUri(null), isNull);
      expect(safeHttpUri('   '), isNull);
      expect(safeHttpUri('https://'), isNull);
    });
  });
}

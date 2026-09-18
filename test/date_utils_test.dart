import 'package:flutter_test/flutter_test.dart';
import 'package:zynkup/core/utils/date_utils.dart';

void main() {
  group('ZynkDateUtils Tests', () {
    test('parseUtc correctly treats ISO string without offset as UTC', () {
      final nowUtc = DateTime.now().toUtc();
      final naiveIso = '${nowUtc.year.toString().padLeft(4, '0')}-'
          '${nowUtc.month.toString().padLeft(2, '0')}-'
          '${nowUtc.day.toString().padLeft(2, '0')}T'
          '${nowUtc.hour.toString().padLeft(2, '0')}:'
          '${nowUtc.minute.toString().padLeft(2, '0')}:'
          '${nowUtc.second.toString().padLeft(2, '0')}';

      final parsed = ZynkDateUtils.parseUtc(naiveIso);
      expect(parsed, isNotNull);
      final diff = DateTime.now().difference(parsed!).inSeconds.abs();
      expect(diff < 5, isTrue);
    });

    test('formatTimeAgo returns just now for current timestamp', () {
      final nowUtc = DateTime.now().toUtc();
      final naiveIso = nowUtc.toIso8601String().replaceAll('Z', '');
      final formatted = ZynkDateUtils.formatTimeAgo(naiveIso);
      expect(formatted, 'just now');
    });

    test('formatTimeAgo handles minutes, hours, days', () {
      final tenMinsAgo = DateTime.now().toUtc().subtract(const Duration(minutes: 10));
      expect(ZynkDateUtils.formatTimeAgo(tenMinsAgo.toIso8601String()), '10m ago');

      final twoHoursAgo = DateTime.now().toUtc().subtract(const Duration(hours: 2));
      expect(ZynkDateUtils.formatTimeAgo(twoHoursAgo.toIso8601String()), '2h ago');

      final threeDaysAgo = DateTime.now().toUtc().subtract(const Duration(days: 3));
      expect(ZynkDateUtils.formatTimeAgo(threeDaysAgo.toIso8601String()), '3d ago');
    });
  });
}

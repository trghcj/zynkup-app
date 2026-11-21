import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynkup/core/api/api_service.dart';
import 'package:zynkup/core/theme/app_theme.dart';
import 'package:zynkup/features/clubs/widgets/club_chat_widget.dart';

void main() {
  // flutter_test answers every real HTTP request with an error, which is
  // exactly the "offline / server unreachable" case these screens handle.
  group('load failures are distinguishable from empty results', () {
    test('fetch* methods throw instead of returning an empty list', () async {
      await expectLater(ApiService.fetchFeed(), throwsA(isA<ApiException>()));
      await expectLater(ApiService.fetchEvents(force: true), throwsA(isA<ApiException>()));
    });

    test('get* methods still return an empty list for existing callers', () async {
      expect(await ApiService.getFeed(), isEmpty);
      expect(await ApiService.getEvents(force: true), isEmpty);
    });
  });

  group('club chat colours follow the theme', () {
    Future<Color?> questionColor(WidgetTester tester, ThemeData theme) async {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: ChatPollCard(
            poll: const {'question': 'Q?', 'options': ['A', 'B'], 'votes': {}},
            currentUserId: 1,
            isMine: false,
            onVote: (_) {},
          ),
        ),
      ));
      return tester.widget<Text>(find.text('Q?')).style?.color;
    }

    testWidgets('light theme uses dark text on light bubbles', (tester) async {
      expect(await questionColor(tester, ThemeData(brightness: Brightness.light)), ZynkColors.lightText);
    });

    testWidgets('dark theme keeps the original light text', (tester) async {
      expect(await questionColor(tester, ThemeData(brightness: Brightness.dark)), ZynkColors.offWhite);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynkup/core/widgets/poll_composer.dart';
import 'package:zynkup/features/clubs/widgets/club_chat_widget.dart';
import 'package:zynkup/features/feed/screens/feed_tab.dart';

void main() {
  group('validatePoll', () {
    test('accepts a question with two options and ignores blanks', () {
      expect(validatePoll('Lunch?', ['Pizza', ' ', 'Pasta']), isNull);
    });

    test('rejects invalid polls', () {
      expect(validatePoll('  ', ['A', 'B']), isNotNull);
      expect(validatePoll('Q', ['A', '  ']), isNotNull);
      expect(validatePoll('Q', List.generate(11, (i) => '$i')), isNotNull);
      expect(validatePoll('Q', ['Yes', 'yes']), isNotNull);
      expect(validatePoll('Q', ['A', 'b' * 101]), isNotNull);
      expect(validatePoll('q' * 301, ['A', 'B']), isNotNull);
    });
  });

  testWidgets('poll composer returns a trimmed poll and blocks invalid input', (tester) async {
    PollDraft? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showPollComposer(context),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Submitting empty shows an error and keeps the sheet open.
    await tester.tap(find.byKey(const Key('poll_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Add a question for your poll'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('poll_question')), '  Meet when? ');
    await tester.enterText(find.byKey(const Key('poll_option_0')), ' Monday ');
    await tester.enterText(find.byKey(const Key('poll_option_1')), 'Tuesday');
    await tester.tap(find.text('Add option'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('poll_option_2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('poll_submit')));
    await tester.pumpAndSettle();
    expect(result?.question, 'Meet when?');
    expect(result?.options, ['Monday', 'Tuesday']);
  });

  testWidgets('feed poll highlights my vote and lets me pick another option', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PollWidget(
          poll: const {
            'question': 'Hey',
            'options': ['What', 'No', 'Yes'],
            'votes': {'1': 1, '2': 2},
            'my_vote': 2,
          },
          onVote: tapped.add,
        ),
      ),
    ));

    // Only my choice gets the tick and the change-vote hint is shown.
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    final yesRow = find.ancestor(of: find.text('Yes'), matching: find.byType(Row)).first;
    expect(find.descendant(of: yesRow, matching: find.byIcon(Icons.check_circle_rounded)), findsOneWidget);
    expect(find.textContaining('Tap another option to change your vote'), findsOneWidget);

    await tester.tap(find.text('No'));
    expect(tapped, [1]);
  });

  testWidgets('feed poll without my vote shows no tick', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PollWidget(
          poll: const {'question': 'Q', 'options': ['A', 'B'], 'votes': {}, 'my_vote': null},
          onVote: (_) {},
        ),
      ),
    ));
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    expect(find.text('0 votes'), findsOneWidget);
  });

  testWidgets('chat poll card shows results and reports taps', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChatPollCard(
          poll: const {
            'question': 'Pizza?',
            'options': ['Yes', 'No'],
            'votes': {'1': 0, '2': 0, '3': 1, '7': 0},
          },
          currentUserId: 7,
          isMine: false,
          onVote: tapped.add,
        ),
      ),
    ));

    expect(find.text('Pizza?'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('4 votes'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.tap(find.text('No'));
    expect(tapped, [1]);
  });
}

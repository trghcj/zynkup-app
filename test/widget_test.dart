import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynkup/features/auth/screens/splash_screen.dart';
import 'package:zynkup/main.dart';

void main() {
  testWidgets('App builds and shows the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(SplashScreen), findsOneWidget);

    // The splash routes to Home after a 1s delay, which needs platform plugins
    // (secure storage, network) that don't exist in widget tests. Unmount the
    // app first, then let the pending timer finish so the test ends cleanly.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}

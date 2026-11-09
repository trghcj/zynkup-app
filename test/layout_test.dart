import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zynkup/core/theme/app_theme.dart';

void main() {
  Future<List<double>> spacingAt(WidgetTester tester, double width) async {
    late List<double> values;
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: Builder(builder: (context) {
        values = [
          ZynkLayout.gutter(context),
          ZynkLayout.cardPadding(context),
          ZynkLayout.cardGap(context),
        ];
        return const SizedBox();
      }),
    ));
    return values;
  }

  testWidgets('phones get tighter gutters and card padding', (tester) async {
    expect(await spacingAt(tester, 360), [12, 12, 12]);
    expect(await spacingAt(tester, 599), [12, 12, 12]);
  });

  testWidgets('tablets and web keep the original spacing', (tester) async {
    expect(await spacingAt(tester, 600), [20, 16, 20]);
    expect(await spacingAt(tester, 1280), [20, 16, 20]);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:zynkup/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
  });
}

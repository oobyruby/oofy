import 'package:flutter_test/flutter_test.dart';
import 'package:oofy_app/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    // Pump your real root widget (whatever your main.dart exposes)
    await tester.pumpWidget(const oofy_app());

    // Basic sanity check: the app title text exists somewhere
    expect(find.text('oofy'), findsOneWidget);
  });
}

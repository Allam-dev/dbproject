import 'package:flutter_test/flutter_test.dart';
import 'package:dbproject/main.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DisasterReliefApp());
    expect(find.text('Disaster Relief Registry'), findsOneWidget);
  });
}

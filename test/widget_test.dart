import 'package:flutter_test/flutter_test.dart';
import 'package:groove/main.dart';

void main() {
  testWidgets('Groove app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GrooveApp());
    expect(find.text('Groove'), findsWidgets);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:supermarket/main.dart';

void main() {
  testWidgets('renders the supermarket login screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SupermarketApp());

    expect(find.text('Supermarket'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('اسم المستخدم'), findsOneWidget);
  });
}

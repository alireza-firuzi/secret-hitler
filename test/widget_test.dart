import 'package:flutter_test/flutter_test.dart';
import 'package:secret_hitler/main.dart';

void main() {
  testWidgets('Secret Hitler online setup loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SecretHitlerApp());

    // Verify that the logo branding is shown
    expect(find.text('راز'), findsOneWidget);
    expect(find.text('هیتلر'), findsOneWidget);

    // Verify that the online lobby options are shown
    expect(find.text('بازی آنلاین'), findsOneWidget);
    expect(find.text('نام شما'), findsOneWidget);
    expect(find.text('ساخت لابی'), findsOneWidget);
    expect(find.text('ورود به لابی'), findsOneWidget);
  });
}

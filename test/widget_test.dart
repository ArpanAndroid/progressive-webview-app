import 'package:flutter_test/flutter_test.dart';
import 'package:cricket_batting/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Progressive WebView app smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProgressiveWebViewApp());
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Progressive App'), findsOneWidget);
  });
}

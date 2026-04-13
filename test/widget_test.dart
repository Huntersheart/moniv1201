import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:slgnara_collar/app/app.dart';

void main() {
  testWidgets('Home screen loads', (WidgetTester tester) async {
    Get.testMode = true;
    await tester.pumpWidget(const App());
    await tester.pump(); // splash
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsOneWidget);
  });
}

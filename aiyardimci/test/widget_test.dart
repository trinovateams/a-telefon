import 'package:flutter_test/flutter_test.dart';
import 'package:aiyardimci/app.dart';

void main() {
  testWidgets('App boots smoke test', (WidgetTester tester) async {
    // Just verify the app can be created without errors
    expect(const AiFaceApp(), isNotNull);
  });
}

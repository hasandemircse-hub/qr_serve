import 'package:flutter_test/flutter_test.dart';

import 'package:edge_frontend/auth/auth_session.dart';
import 'package:edge_frontend/main.dart';

void main() {
  testWidgets('QuickServe Edge app builds', (WidgetTester tester) async {
    final auth = AuthSession();
    await tester.pumpWidget(QuickServeEdgeApp(auth: auth));
    await tester.pumpAndSettle();
    expect(find.textContaining('Giriş'), findsWidgets);
  });
}

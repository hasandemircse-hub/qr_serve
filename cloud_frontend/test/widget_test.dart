import 'package:flutter_test/flutter_test.dart';

import 'package:cloud_frontend/auth/cloud_auth_session.dart';
import 'package:cloud_frontend/main.dart';

void main() {
  testWidgets('Cloud app builds', (WidgetTester tester) async {
    final auth = CloudAuthSession();
    await tester.pumpWidget(QuickServeCloudApp(auth: auth));
    await tester.pump();
    expect(find.textContaining('QuickServe Cloud'), findsWidgets);
  });
}

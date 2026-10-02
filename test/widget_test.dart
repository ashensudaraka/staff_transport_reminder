import 'package:flutter_test/flutter_test.dart';
import 'package:staff_transport_reminder/main.dart';

void main() {
  testWidgets('StaffTransportApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const StaffTransportApp());

    // Verify that the title text appears.
    expect(find.text('Staff Transport'), findsOneWidget);
  });
}


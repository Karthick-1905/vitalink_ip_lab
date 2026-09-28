import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/admin/admin_mutation_dialog.dart';

void main() {
  testWidgets('one-time password requires explicit acknowledgment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAdminCredentialResult(
                context,
                title: 'Doctor registered',
                successMessage: 'Share securely.',
                temporaryPassword: 'temporary-secret',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('temporary-secret'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Done'))
          .onPressed,
      isNull,
    );
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.text('temporary-secret'), findsOneWidget);

    await tester.tap(find.byKey(const Key('credential-acknowledgment')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Done'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('temporary-secret'), findsNothing);
  });
}

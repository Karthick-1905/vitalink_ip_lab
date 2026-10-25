import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/doctor/widgets/report_review_sheet.dart';

void main() {
  testWidgets(
    'review saves explicitly and controller survives route exit animation',
    (tester) async {
      String? savedNotes;
      bool? savedReview;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ReportReviewSheet(
                    initialNotes: '',
                    onSave: (notes, reviewed) async {
                      savedNotes = notes;
                      savedReview = reviewed;
                    },
                  ),
                ),
                child: const Text('Open review'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open review'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      await tester.enterText(
        find.byType(TextField),
        'Reviewed with individual target',
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save review'));
      await tester.tap(find.text('Save review'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(savedNotes, 'Reviewed with individual target');
      expect(savedReview, isTrue);
      expect(find.byType(ReportReviewSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed save keeps notes and permits retry without marking review implicitly',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReportReviewSheet(
              initialNotes: 'Keep these notes',
              onSave: (_, reviewed) async {
                expect(reviewed, isFalse);
                throw Exception('Test request failure');
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Save review'));
      await tester.pumpAndSettle();
      expect(find.text('Keep these notes'), findsOneWidget);
      expect(find.byType(ReportReviewSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

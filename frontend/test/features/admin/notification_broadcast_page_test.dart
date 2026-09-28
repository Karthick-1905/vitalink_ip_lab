import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/admin/data/admin_repository.dart';
import 'package:frontend/features/admin/notification_broadcast_page.dart';

class _FakeNotificationAdminRepository extends AdminRepository {
  _FakeNotificationAdminRepository() : super(apiClient: ApiClient());

  int broadcastCalls = 0;
  String? lastTitle;
  String? lastMessage;
  String? lastTarget;
  List<String>? lastUserIds;
  String? lastPriority;

  List<Map<String, dynamic>> doctorList = [
    {
      '_id': '507f1f77bcf86cd799439011',
      'login_id': 'DOC001',
      'profile_id': {
        'name': 'Dr. Strange',
        'department': 'Cardiology',
      },
    },
    {
      '_id': '507f1f77bcf86cd799439012',
      'login_id': 'DOC002',
      'profile_id': {
        'name': 'Dr. House',
        'department': 'Diagnostics',
      },
    },
  ];

  List<Map<String, dynamic>> patientList = [
    {
      '_id': '507f1f77bcf86cd799439021',
      'login_id': 'PAT001',
      'profile_id': {
        'op_number': 'OP100',
        'demographics': {
          'name': 'John Doe',
        },
      },
    },
  ];

  bool shouldFailDoctors = false;
  bool shouldFailPatients = false;

  @override
  Future<Map<String, dynamic>> getAllDoctors({
    int page = 1,
    int limit = 20,
    String? department,
    String? isActive,
    String? search,
  }) async {
    if (shouldFailDoctors) {
      throw Exception('Forbidden: Cross-tenant access is not allowed');
    }
    return {'doctors': doctorList};
  }

  @override
  Future<Map<String, dynamic>> getAllPatients({
    int page = 1,
    int limit = 20,
    String? assignedDoctorId,
    String? accountStatus,
    String? search,
  }) async {
    if (shouldFailPatients) {
      throw Exception('Forbidden: Cross-tenant access is not allowed');
    }
    return {'patients': patientList};
  }

  @override
  Future<Map<String, dynamic>> broadcastNotification({
    required String title,
    required String message,
    required String target,
    List<String>? userIds,
    String priority = 'MEDIUM',
  }) async {
    broadcastCalls++;
    lastTitle = title;
    lastMessage = message;
    lastTarget = target;
    lastUserIds = userIds;
    lastPriority = priority;
    return {'message': 'Notification broadcast successful'};
  }
}

void main() {
  testWidgets('renders all target options including specific doctor and specific patient', (
    tester,
  ) async {
    final repo = _FakeNotificationAdminRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationBroadcastPage(repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('All Users'), findsOneWidget);
    expect(find.text('All Doctors'), findsOneWidget);
    expect(find.text('All Patients'), findsOneWidget);
    expect(find.text('Specific Doctor'), findsOneWidget);
    expect(find.text('Specific Patient'), findsOneWidget);
  });

  testWidgets('selecting Specific Doctor fetches doctors and allows broadcast to specific doctor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeNotificationAdminRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationBroadcastPage(repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Fill in title and message
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Notification Title'),
      'Important Doctor Notice',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Message'),
      'Please review new INR protocols.',
    );

    // Tap Specific Doctor
    await tester.ensureVisible(find.text('Specific Doctor'));
    await tester.tap(find.text('Specific Doctor'));
    await tester.pumpAndSettle();

    expect(find.text('Target Doctor'), findsOneWidget);
    expect(find.text('Select Doctor'), findsOneWidget);

    // Open dropdown and select Dr. Strange
    await tester.tap(find.text('Select Doctor'));
    await tester.pumpAndSettle();

    final itemFinder = find.text('Dr. Strange (Cardiology • ID: DOC001)');
    expect(itemFinder, findsWidgets);
    await tester.tap(itemFinder.last);
    await tester.pumpAndSettle();

    // Tap Send Notification
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Send Notification'));
    await tester.tap(find.widgetWithText(FilledButton, 'Send Notification'));
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('Send Notification?'), findsOneWidget);
    expect(
      find.text('This will send a MEDIUM priority notification to doctor Dr. Strange.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();

    expect(repo.broadcastCalls, 1);
    expect(repo.lastTitle, 'Important Doctor Notice');
    expect(repo.lastMessage, 'Please review new INR protocols.');
    expect(repo.lastTarget, 'SPECIFIC');
    expect(repo.lastUserIds, ['507f1f77bcf86cd799439011']);
  });

  testWidgets('selecting Specific Patient and entering User ID manually validates 24-char hex', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeNotificationAdminRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationBroadcastPage(repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Fill in title and message
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Notification Title'),
      'Dosage Reminder',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Message'),
      'Take 5mg Warfarin with food.',
    );

    // Tap Specific Patient
    await tester.ensureVisible(find.text('Specific Patient'));
    await tester.tap(find.text('Specific Patient'));
    await tester.pumpAndSettle();

    expect(find.text('Target Patient'), findsOneWidget);

    // Tap Enter ID manually
    await tester.ensureVisible(find.text('Enter ID manually'));
    await tester.tap(find.text('Enter ID manually'));
    await tester.pumpAndSettle();

    // Enter invalid hex
    final idField = find.widgetWithText(TextFormField, 'Patient User ID (24-char hex)');
    await tester.ensureVisible(idField);
    await tester.enterText(idField, 'invalid-id');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Send Notification'));
    await tester.tap(find.widgetWithText(FilledButton, 'Send Notification'));
    await tester.pumpAndSettle();

    expect(find.text('Must be a 24-character hexadecimal ID'), findsOneWidget);
    expect(repo.broadcastCalls, 0);

    // Enter valid 24-char hex ObjectId
    await tester.enterText(idField, '507f1f77bcf86cd799439099');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Send Notification'));
    await tester.tap(find.widgetWithText(FilledButton, 'Send Notification'));
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('Send Notification?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();

    expect(repo.broadcastCalls, 1);
    expect(repo.lastTitle, 'Dosage Reminder');
    expect(repo.lastMessage, 'Take 5mg Warfarin with food.');
    expect(repo.lastTarget, 'SPECIFIC');
    expect(repo.lastUserIds, ['507f1f77bcf86cd799439099']);
  });

  testWidgets('handles directory load error gracefully with manual ID fallback', (
    tester,
  ) async {
    final repo = _FakeNotificationAdminRepository()..shouldFailDoctors = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationBroadcastPage(repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Specific Doctor'));
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to load doctors directory in current administrator scope.'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextFormField, 'Doctor User ID (24-char hex)'),
      findsOneWidget,
    );
  });
}

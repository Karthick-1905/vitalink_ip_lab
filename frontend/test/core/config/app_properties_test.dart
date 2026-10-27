import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_properties.dart';
import 'package:frontend/core/config/property_defaults.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'offline startup retains cached properties and failed refresh does not erase them',
    () async {
      final client = Dio(BaseOptions(baseUrl: 'https://properties.invalid'));
      client.httpClientAdapter = _Adapter(offline: true);
      final properties = AppProperties(client: client);
      SharedPreferences.setMockInitialValues({
        properties.cacheKey: jsonEncode({
          'schemaVersion': 1,
          'revision': 3,
          'properties': {'branding.appName': 'Cached hospital'},
        }),
      });
      await properties.initialize();
      await properties.refresh(force: true);
      expect(properties.text('branding.appName'), 'Cached hospital');
      expect(properties.revision, 3);
      properties.dispose();
    },
  );

  test(
    'successful public refresh persists the validated snapshot without authorization headers',
    () async {
      final client = Dio(BaseOptions(baseUrl: 'https://properties.invalid'));
      final adapter = _Adapter();
      client.httpClientAdapter = adapter;
      final properties = AppProperties(client: client);
      SharedPreferences.setMockInitialValues({});
      await properties.initialize();
      await properties.refresh(force: true);
      expect(properties.text('branding.appName'), 'Remote hospital');
      expect(
        adapter.headers.keys.any((key) => key.toLowerCase() == 'authorization'),
        isFalse,
      );
      final preferences = await SharedPreferences.getInstance();
      expect(
        jsonDecode(preferences.getString(properties.cacheKey)!)['revision'],
        1,
      );
      properties.dispose();
    },
  );
  test(
    'bundled defaults work before any network or storage initialization',
    () {
      final properties = AppProperties(client: Dio());
      expect(properties.text('branding.appName'), 'VitaLink');
      expect(properties.color('theme.primary'), const Color(0xFF648FFF));
      properties.dispose();
    },
  );

  test('invalid snapshots preserve the entire last working configuration', () {
    final properties = AppProperties(client: Dio());
    expect(
      properties.apply({
        'schemaVersion': 1,
        'revision': 2,
        'properties': {'branding.appName': 'Hospital'},
      }),
      isTrue,
    );
    for (final payload in [
      {'schemaVersion': 2, 'revision': 3, 'properties': {}},
      {
        'schemaVersion': 1,
        'revision': 3,
        'properties': {'branding.appName': 'Wrong', 'theme.primary': 'red'},
      },
      {
        'schemaVersion': 1,
        'revision': 3,
        'properties': {'asset.hospitalLogo': 'http://example.com/logo.png'},
      },
      {
        'schemaVersion': 1,
        'revision': 3,
        'properties': {
          'notification.dosage.message': 'Missing clinical values',
        },
      },
      {
        'schemaVersion': 1,
        'revision': 1,
        'properties': {'branding.appName': 'Stale'},
      },
    ]) {
      expect(properties.apply(payload), isFalse);
      expect(properties.text('branding.appName'), 'Hospital');
      expect(properties.revision, 2);
    }
    properties.dispose();
  });

  test(
    'missing keys fall back and newer unknown keys do not break older clients',
    () {
      final properties = AppProperties(client: Dio());
      expect(
        properties.apply({
          'schemaVersion': 1,
          'revision': 1,
          'properties': {'future.key': 'new'},
        }),
        isTrue,
      );
      expect(
        properties.text('asset.hospitalLogo'),
        propertyDefaults['asset.hospitalLogo'],
      );
      properties.dispose();
    },
  );

  test('template arguments are substituted once', () {
    final properties = AppProperties(client: Dio());
    expect(
      properties.text(
        'notification.dosage.message',
        arguments: {'drugName': '{dose}', 'dose': '2'},
      ),
      'Take your {dose} dose - 2mg today.',
    );
    properties.dispose();
  });

  testWidgets('publication changes screen text without losing a form draft', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'unsaved clinical form');
    await tester.pumpWidget(
      AppPropertyScope(child: MaterialApp(home: _PropertyForm(controller))),
    );
    expect(find.text('VitaLink'), findsOneWidget);
    AppProperties.instance.apply({
      'schemaVersion': 1,
      'revision': 1,
      'properties': {'branding.appName': 'Updated hospital'},
    });
    await tester.pump();
    expect(find.text('Updated hospital'), findsOneWidget);
    expect(controller.text, 'unsaved clinical form');
    AppProperties.instance.apply({
      'schemaVersion': 1,
      'revision': 2,
      'properties': {},
    });
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter({this.offline = false});
  final bool offline;
  Map<String, dynamic> headers = {};
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    headers = options.headers;
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'data': {
          'schemaVersion': 1,
          'revision': 1,
          'properties': {'branding.appName': 'Remote hospital'},
        },
      }),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _PropertyForm extends StatelessWidget {
  const _PropertyForm(this.controller);
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return Scaffold(
      body: Column(
        children: [
          Text(AppCopy.text('branding.appName')),
          TextField(controller: controller),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/strings.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/admin/data/admin_repository.dart';
import 'package:frontend/features/admin/presentation_properties_editor.dart';

class _Repository extends AdminRepository {
  _Repository() : super(apiClient: ApiClient());
  int reads = 0;
  Map<String, dynamic>? mutation;
  final Map<String, dynamic> state = {
    'version': 0,
    'published_revision': 0,
    'draft': <String, dynamic>{},
    'history': <dynamic>[],
    'defaults': {
      'branding.appName': 'VitaLink',
      'theme.primary': '#648FFF',
      'asset.hospitalLogo': 'assets/images/psg_logo_2.png',
      'asset.instituteLogo': 'assets/images/psg_ims.png',
      for (int i = 0; i < 23; i++) 'text.example_$i': 'Example screen $i',
    },
  };
  @override
  Future<Map<String, dynamic>> getPresentationProperties() async {
    reads++;
    return Map.of(state);
  }

  @override
  Future<Map<String, dynamic>> updatePresentationProperties(
    Map<String, dynamic> data,
  ) async {
    mutation = data;
    state['version'] = (state['version'] as int) + 1;
    state['draft'] = data['properties'] ?? state['draft'];
    return Map.of(state);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const fontDirectory = String.fromEnvironment('PROPERTY_EDITOR_FONT_DIR');
    if (fontDirectory.isEmpty) return;
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(
          File(
            '$fontDirectory/${entry.value}',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
    }
  });

  testWidgets('previews both draft logos, including uploaded local API images', (
    tester,
  ) async {
    final repository = _Repository();
    final imageId = List.filled(64, 'a').join();
    repository.state['draft'] = {
      'asset.hospitalLogo': 'brand-asset:$imageId',
      'asset.instituteLogo': 'https://client.example/institute.png',
    };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PresentationPropertiesEditor(
              repository: repository,
              canManage: true,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Application properties'));
    await tester.pumpAndSettle();
    final hospital = tester.widget<Image>(
      find.byKey(const ValueKey('preview.asset.hospitalLogo')),
    );
    expect(
      (hospital.image as NetworkImage).url,
      '${AppStrings.apiBaseUrl}${AppStrings.apiPathPrefix}/app-properties/assets/$imageId',
    );
    final institute = tester.widget<Image>(
      find.byKey(const ValueKey('preview.asset.instituteLogo')),
    );
    expect(
      (institute.image as NetworkImage).url,
      'https://client.example/institute.png',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('loads lazily, searches properties and saves a versioned draft', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PresentationPropertiesEditor(
              repository: repository,
              canManage: true,
            ),
          ),
        ),
      ),
    );
    expect(repository.reads, 0);
    await tester.tap(find.text('Application properties'));
    await tester.pumpAndSettle();
    expect(repository.reads, 1);
    expect(find.text('Page 1 of 2'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Find a property'),
      'branding.appName',
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('branding.appName')),
      'My Hospital',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Save draft'));
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(repository.mutation?['action'], 'save');
    expect(repository.mutation?['expectedVersion'], 0);
    expect(
      (repository.mutation?['properties'] as Map)['branding.appName'],
      'My Hospital',
    );
  });

  testWidgets(
    'read access hides mutations and the editor fits desktop and mobile',
    (tester) async {
      final boundary = GlobalKey();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              appBar: AppBar(title: const Text('Platform Configuration')),
              body: SingleChildScrollView(
                child: PresentationPropertiesEditor(
                  repository: _Repository(),
                  canManage: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Application properties'));
      await tester.pumpAndSettle();
      expect(find.text('Save draft'), findsNothing);
      expect(find.text('Upload image'), findsNothing);
      expect(tester.takeException(), isNull);
      Future<void> capture(String name) async {
        if (!const bool.fromEnvironment('PROPERTY_EDITOR_SCREENSHOTS')) return;
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '../build/property-editor-$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('desktop');
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture('mobile');
    },
  );
}

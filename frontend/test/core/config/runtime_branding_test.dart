import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_properties.dart';
import 'package:frontend/core/widgets/admin/admin_scaffold.dart';

void main() {
  testWidgets('admin branding refreshes in place across navigation layouts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() {
      AppProperties.instance.apply({
        'schemaVersion': 1,
        'revision': AppProperties.instance.revision + 1,
        'properties': <String, String>{},
      });
    });
    final form = TextEditingController(text: 'Unsaved work');
    await tester.pumpWidget(
      AppPropertyScope(
        child: MaterialApp(
          home: AdminScaffold(
            selectedDestinationId: 'overview',
            onDestinationSelected: (_) {},
            destinations: const [
              AdminNavigationItem(
                id: 'overview',
                label: 'Overview',
                icon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard,
              ),
            ],
            body: TextField(controller: form),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('VitaLink'), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).image, isA<AssetImage>());

    AppProperties.instance.apply({
      'schemaVersion': 1,
      'revision': AppProperties.instance.revision + 1,
      'properties': {
        'branding.appName': 'Client Care',
        'asset.hospitalLogo': 'https://client.example/logo.png',
      },
    });
    await tester.pump();
    expect(find.text('Client Care'), findsOneWidget);
    final remote = tester.widget<Image>(find.byType(Image));
    expect(
      (remote.image as NetworkImage).url,
      'https://client.example/logo.png',
    );
    expect(form.text, 'Unsaved work');

    // A failed download keeps the bundled logo available in every layout.
    await tester.pumpAndSettle();
    expect(
      tester.widget<Image>(find.byType(Image).last).image,
      isA<AssetImage>(),
    );
    for (final width in [700.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      await tester.pumpAndSettle();
      if (width < AdminScaffold.tabletBreakpoint) {
        await tester.tap(find.byIcon(Icons.menu));
        await tester.pumpAndSettle();
        expect(find.text('Client Care'), findsOneWidget);
      }
      expect(find.byType(PropertyImage), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(form.text, 'Unsaved work');
    }
    await tester.pumpWidget(const SizedBox());
    form.dispose();
  });
}

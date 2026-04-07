import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';
import 'package:frontend/app/app.dart';
import 'package:frontend/core/di/app_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    try {
      await QueryCache.instance.initialize();
    } catch (e) {
      debugPrint('Failed to initialize QueryCache: $e');
    }
  }

  await NetworkPolicy.instance.initialize();

  final queryClient = AppDependencies.createQueryClient(
    onError: (error) => debugPrint('Query error: $error'),
  );

  runApp(VitalinkApp(queryClient: queryClient));
}

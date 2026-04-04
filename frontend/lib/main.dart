import 'package:flutter/material.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';
import 'package:frontend/app/app.dart';
import 'package:frontend/core/di/app_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await QueryCache.instance.initialize();
  } catch (e) {
    debugPrint('Failed to initialize QueryCache (path_provider may not be available on web): $e');
  }

  await NetworkPolicy.instance.initialize();

  final queryClient = AppDependencies.createQueryClient(
    onError: (error) => debugPrint('Query error: $error'),
  );

  runApp(VitalinkApp(queryClient: queryClient));
}

import 'package:frontend/core/config/app_properties.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';
import 'package:frontend/app/routers.dart';
import 'package:frontend/core/di/theme.dart';

class VitalinkApp extends StatelessWidget {
  const VitalinkApp({super.key, required this.queryClient});

  final QueryClient queryClient;

  @override
  Widget build(BuildContext context) {
    return QueryClientProvider(
      client: queryClient,
      child: AppPropertyScope(
        child: AnimatedBuilder(
          animation: AppProperties.instance,
          builder: (context, _) => MaterialApp(
            navigatorKey: AppRouter.navigatorKey,
            navigatorObservers: [AppRouter.routeTracker],
            title: AppCopy.text('branding.appName'),
            theme: AppTheme.light.copyWith(
              colorScheme: AppTheme.light.colorScheme.copyWith(
                primary: AppProperties.instance.color('theme.primary'),
                secondary: AppProperties.instance.color('theme.secondary'),
                tertiary: AppProperties.instance.color('theme.accent'),
              ),
            ),
            // darkTheme: AppTheme.dark,
            initialRoute: AppRouter.initialRoute,
            routes: AppRouter.routes,
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    );
  }
}

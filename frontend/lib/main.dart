import 'package:flutter/material.dart';
import 'package:frontend/app/routers.dart';
import 'package:frontend/app/theme.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frontend',
      theme: AppTheme.light,
      // darkTheme: AppTheme.dark,
      // themeMode: ThemeMode.system,
      initialRoute: AppRouter.initialRoute,
      routes: AppRouter.routes,
      debugShowCheckedModeBanner: false,
    );
  }
}

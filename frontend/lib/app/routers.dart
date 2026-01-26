import 'package:flutter/material.dart';
import 'package:frontend/features/login/login_page.dart';

class AppRoutes {
	static const String login = '/login';
	// Add more route names here as needed, e.g.
	// static const String home = '/home';
}

class AppRouter {
	static const String initialRoute = AppRoutes.login;

	static final Map<String, WidgetBuilder> routes = {
		AppRoutes.login: (_) => const LoginPage(),
		// Add other routes here, e.g.
		// AppRoutes.home: (_) => const HomePage(),
	};
}


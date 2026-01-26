import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/app_navbar.dart';

class AppScaffold extends StatelessWidget {
  final String pageTitle;
  final Widget body;
  final Widget? drawer;
  final Color navbarBackgroundColor;

  const AppScaffold({
    super.key,
    required this.pageTitle,
    required this.body,
    this.drawer,
    this.navbarBackgroundColor = const Color(0xFFDCC9E8),
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: drawer,
      body: Column(
        children: [
          AppNavBar(
            pageTitle: pageTitle,
            backgroundColor: navbarBackgroundColor,
          ),
          Expanded(
            child: body,
          ),
        ],
      ),
    );
  }
}

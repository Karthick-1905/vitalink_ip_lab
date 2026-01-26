import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/app_navbar.dart';
import 'package:frontend/core/widgets/doctor_bottom_nav.dart';

class DoctorScaffold extends StatelessWidget {
  final String pageTitle;
  final Widget body;
  final int currentNavIndex;
  final Function(int) onNavChanged;
  final Widget? drawer;
  final Color navbarBackgroundColor;

  const DoctorScaffold({
    super.key,
    required this.pageTitle,
    required this.body,
    required this.currentNavIndex,
    required this.onNavChanged,
    this.drawer,
    this.navbarBackgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: drawer,
      bottomNavigationBar: DoctorBottomNavBar(
        currentIndex: currentNavIndex,
        onTap: onNavChanged,
      ),
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

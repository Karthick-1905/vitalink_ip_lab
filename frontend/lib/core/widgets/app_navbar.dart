import 'package:flutter/material.dart';

class AppNavBar extends StatelessWidget {
  final String pageTitle;
  final VoidCallback? onMenuPressed;
  final Color backgroundColor;

  const AppNavBar({
    super.key,
    required this.pageTitle,
    this.onMenuPressed,
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: backgroundColor,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logos row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 70,
                      child: Image.asset(
                        'assets/images/psg_ims.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 1,
                      height: 70,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 70,
                      child: Image.asset(
                        'assets/images/psg_logo_2.jpg.jpeg',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Page title
                Text(
                  pageTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(
          height: 1,
          thickness: 1,
          color: Colors.grey,
        ),
      ],
    );
  }
}

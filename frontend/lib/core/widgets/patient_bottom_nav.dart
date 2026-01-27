import 'package:flutter/material.dart';

class PatientBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const PatientBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFFE91E63),
      unselectedItemColor: Colors.grey[600],
      elevation: 8,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bloodtype),
          label: 'Update INR',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.medication),
          label: 'Take Dosage',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}

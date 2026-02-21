import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/app/routers.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Smart Health Tracking',
      description:
          'Monitor your health vitals and INR levels with precision and ease using our advanced tracking system.',
      image: 'assets/onboarding/tracking.png',
    ),
    OnboardingData(
      title: 'Team Collaboration',
      description:
          'Work together efficiently and manage your health journey in one centralized platform with doctors and caregivers.',
      image: 'assets/onboarding/collaboration.png',
    ),
    OnboardingData(
      title: 'Real-time Alerts',
      description:
          'Stay informed with instant notifications for your dosage schedules and critical health report updates.',
      image: 'assets/onboarding/alerts.png',
    ),
  ];

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishOnboarding() {
    final args = ModalRoute.of(context)?.settings.arguments;
    // Support both bool (legacy: isDoctor) and String (userType) arguments
    String route;
    if (args is String && args.toUpperCase() == 'ADMIN') {
      route = AppRoutes.adminDashboard;
    } else {
      final bool isDoctor = args is bool ? args : false;
      route = isDoctor ? AppRoutes.doctorDashboard : AppRoutes.patient;
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: TextButton(
                  onPressed: _finishOnboarding,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1E5E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  return OnboardingContent(data: _pages[index]);
                },
              ),
            ),

            // Bottom Navigation
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  _buildNavButton(
                    icon: Icons.chevron_left,
                    onTap: _previousPage,
                    isVisible: _currentPage > 0,
                  ),

                  // Indicators
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => _buildIndicator(index == _currentPage),
                    ),
                  ),

                  // Next/Forward Button
                  _buildNavButton(
                    icon: Icons.chevron_right,
                    onTap: _nextPage,
                    isVisible: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isVisible,
  }) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: isVisible ? onTap : null,
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E5E),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
      ),
    );
  }

  Widget _buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 4,
      width: isActive ? 24 : 12,
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF1E1E5E)
            : const Color(0xFF1E1E5E).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class OnboardingContent extends StatelessWidget {
  final OnboardingData data;

  const OnboardingContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            data.image,
            height: MediaQuery.of(context).size.height * 0.4,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 40),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.black54,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final String image;

  OnboardingData({
    required this.title,
    required this.description,
    required this.image,
  });
}

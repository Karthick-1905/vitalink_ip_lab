import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/index.dart';
import 'package:frontend/app/routers.dart';
import 'package:frontend/services/patient_service.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';

class PatientProfilePage extends StatefulWidget {
  const PatientProfilePage({super.key});

  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  final int _currentNavIndex = 4;

  @override
  Widget build(BuildContext context) {
    return UseQuery<Map<String, dynamic>>(
      options: QueryOptions<Map<String, dynamic>>(
        queryKey: const ['patient', 'profile_full'],
        queryFn: () async {
          final profile = await PatientService.getProfile();
          final history = await PatientService.getINRHistory();
          final latest = await PatientService.getLatestINR();
          return {
            'profile': profile,
            'history': history,
            'latest': latest,
          };
        },
      ),
      builder: (context, query) {
        if (query.isLoading) {
          return const PatientScaffold(
            pageTitle: '@ Profile Page',
            currentNavIndex: 0,
            onNavChanged: _dummyOnNavChanged,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (query.isError) {
          return PatientScaffold(
            pageTitle: '@ Profile Page',
            currentNavIndex: 0,
            onNavChanged: (index) => _handleNav(index),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${query.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () => query.refetch(), child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        if (!query.hasData) {
          return const PatientScaffold(
            pageTitle: '@ Profile Page',
            currentNavIndex: 0,
            onNavChanged: _dummyOnNavChanged,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = query.data!;
        final profile = data['profile'] as Map<String, dynamic>;

        return PatientScaffold(
          pageTitle: 'My Profile',
          currentNavIndex: _currentNavIndex,
          onNavChanged: (index) => _handleNav(index),
          bodyDecoration: const BoxDecoration(
            color: Color(0xFFF9FAFB),
          ),
          body: RefreshIndicator(
            onRefresh: () async => query.refetch(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Section (Avatar, Name, Info Cards, Details, Actions)
                  PatientProfileContent(
                    profile: profile,
                    onProfileUpdated: () => query.refetch(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void _dummyOnNavChanged(int index) {}

  void _handleNav(int index) {
    if (index == _currentNavIndex) return;
    switch (index) {
      case 0: Navigator.of(context).pushReplacementNamed(AppRoutes.patient); break;
      case 1: Navigator.of(context).pushReplacementNamed(AppRoutes.patientUpdateINR); break;
      case 2: Navigator.of(context).pushReplacementNamed(AppRoutes.patientTakeDosage); break;
      case 3: Navigator.of(context).pushReplacementNamed(AppRoutes.patientHealthReports); break;
      case 4: break;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/core/query/patient_query_keys.dart';
import 'package:frontend/core/widgets/index.dart';
import 'package:frontend/features/patient/patient_health_reports_page.dart';
import 'package:frontend/features/patient/patient_page.dart';
import 'package:frontend/features/patient/patient_profile_page.dart';
import 'package:frontend/features/patient/patient_take_dosage_page.dart';
import 'package:frontend/features/patient/patient_update_inr_page.dart';

class PatientDashboardShellPage extends StatefulWidget {
  final int initialTabIndex;

  const PatientDashboardShellPage({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<PatientDashboardShellPage> createState() =>
      _PatientDashboardShellPageState();
}

class _PatientDashboardShellPageState extends State<PatientDashboardShellPage> {
  late int _currentNavIndex;
  late final List<Widget> _tabs;
  bool _hasShownUpdatesPopup = false;

  @override
  void initState() {
    super.initState();
    _currentNavIndex = widget.initialTabIndex.clamp(0, 4);
    _tabs = [
      PatientPage(embedInShell: true, onTabChanged: _onNavChanged),
      PatientUpdateINRPage(embedInShell: true, onTabChanged: _onNavChanged),
      PatientTakeDosagePage(embedInShell: true, onTabChanged: _onNavChanged),
      PatientHealthReportsPage(embedInShell: true, onTabChanged: _onNavChanged),
      PatientProfilePage(embedInShell: true, onTabChanged: _onNavChanged),
    ];
  }

  @override
  void didUpdateWidget(covariant PatientDashboardShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newIndex = widget.initialTabIndex.clamp(0, 4);
    if (newIndex != _currentNavIndex) {
      setState(() => _currentNavIndex = newIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UseQuery<int>(
      options: QueryOptions<int>(
        queryKey: PatientQueryKeys.doctorUpdatesUnread(),
        queryFn: () async {
          final profile = await AppDependencies.patientRepository.getProfile();
          return (profile['doctorUpdatesUnreadCount'] as num?)?.toInt() ?? 0;
        },
      ),
      builder: (context, query) {
        final unreadCount = query.data ?? 0;
        _maybeShowUnreadPopup(unreadCount);

        return PatientScaffold(
          pageTitle: _titleForIndex(_currentNavIndex),
          currentNavIndex: _currentNavIndex,
          onNavChanged: _onNavChanged,
          unreadDoctorUpdatesCount: unreadCount,
          bodyDecoration: _decorationForIndex(_currentNavIndex),
          body: IndexedStack(
            index: _currentNavIndex,
            children: _tabs,
          ),
        );
      },
    );
  }

  void _onNavChanged(int index) {
    if (index == _currentNavIndex) return;
    setState(() => _currentNavIndex = index);
  }

  void _maybeShowUnreadPopup(int unreadCount) {
    if (_hasShownUpdatesPopup || unreadCount <= 0) return;

    _hasShownUpdatesPopup = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('New Doctor Updates'),
            content: Text(
              unreadCount == 1
                  ? 'You have 1 unread doctor update.'
                  : 'You have $unreadCount unread doctor updates.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _onNavChanged(4);
                },
                child: const Text('View Updates'),
              ),
            ],
          );
        },
      );
    });
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 1:
        return 'Update INR';
      case 2:
        return 'Dosage Management';
      case 3:
        return 'Health Reports';
      case 4:
        return 'My Profile';
      case 0:
      default:
        return 'Dashboard';
    }
  }

  Decoration _decorationForIndex(int index) {
    if (index == 4) {
      return const BoxDecoration(color: Color(0xFFF9FAFB));
    }

    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFC8B5E1), Color(0xFFF8C7D7)],
      ),
    );
  }
}

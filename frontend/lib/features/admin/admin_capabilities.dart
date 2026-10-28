import 'package:frontend/core/config/app_properties.dart';
import 'package:flutter/material.dart';
import 'package:frontend/features/admin/models/admin_access_model.dart';

abstract final class AdminCapabilities {
  static const platformHospitalsRead = 'platform.hospitals.read';
  static const platformHospitalsManage = 'platform.hospitals.manage';
  static const platformAdminAccountsRead = 'platform.admin_accounts.read';
  static const platformAdminAccountsManage = 'platform.admin_accounts.manage';
  static const platformRolePolicyRead = 'platform.role_policy.read';
  static const platformRolePolicyManage = 'platform.role_policy.manage';
  static const platformAuditRead = 'platform.audit.read';
  static const platformAnalyticsRead = 'platform.analytics.read';
  static const platformBillingRead = 'platform.billing.read';
  static const platformBillingManage = 'platform.billing.manage';
  static const platformSystemConfigRead = 'platform.system_config.read';
  static const platformSystemConfigManage = 'platform.system_config.manage';
  static const platformSystemHealthRead = 'platform.system_health.read';
  static const platformNotificationsBroadcast =
      'platform.notifications.broadcast';

  static const tenantDashboardRead = 'tenant.dashboard.read';
  static const tenantDoctorsRead = 'tenant.doctors.read';
  static const tenantDoctorsManage = 'tenant.doctors.manage';
  static const tenantPatientsRead = 'tenant.patients.read';
  static const tenantPatientsManage = 'tenant.patients.manage';
  static const tenantPatientsAssign = 'tenant.patients.assign';
  static const tenantAccountsStatusManage = 'tenant.accounts.status.manage';
  static const tenantCredentialsReset = 'tenant.credentials.reset';
  static const tenantAuditRead = 'tenant.audit.read';
  static const tenantAnalyticsRead = 'tenant.analytics.read';
  static const tenantBillingRead = 'tenant.billing.read';
  static const tenantBillingCheckout = 'tenant.billing.checkout';
  static const tenantNotificationsBroadcast = 'tenant.notifications.broadcast';
  static const tenantOperationsHealthRead = 'tenant.operations_health.read';

  /// Matches `GET /statistics/admin` (`platform.analytics.read` | `tenant.dashboard.read`).
  static const dashboardRead = [tenantDashboardRead, platformAnalyticsRead];

  /// Matches trends/workload/period analytics routes (`platform.analytics.read` | `tenant.analytics.read`).
  static const analyticsRead = [platformAnalyticsRead, tenantAnalyticsRead];
  static const billingRead = [platformBillingRead, tenantBillingRead];
  static const auditRead = [platformAuditRead, tenantAuditRead];
  static const notificationActions = [
    platformNotificationsBroadcast,
    tenantNotificationsBroadcast,
  ];
}

class AdminCapabilityInfo {
  const AdminCapabilityInfo({
    required this.label,
    required this.description,
    required this.area,
    required this.icon,
  });

  final String label;
  final String description;
  final String area;
  final IconData icon;
}

Map<String, AdminCapabilityInfo> get adminCapabilityInfo =>
    <String, AdminCapabilityInfo>{
      AdminCapabilities.platformHospitalsRead: AdminCapabilityInfo(
        label: AppCopy.text('text.view_hospitals_186a0517'),
        description: AppCopy.text(
          'text.read_the_hospital_directory_and_operational_meta_9670d5c7',
        ),
        area: 'Hospitals',
        icon: Icons.local_hospital_outlined,
      ),
      AdminCapabilities.platformHospitalsManage: AdminCapabilityInfo(
        label: AppCopy.text('text.manage_hospitals_b04fcf31'),
        description: AppCopy.text(
          'text.create_update_suspend_or_reactivate_hospitals_69c4afe6',
        ),
        area: 'Hospitals',
        icon: Icons.local_hospital_outlined,
      ),
      AdminCapabilities.platformAdminAccountsRead: AdminCapabilityInfo(
        label: AppCopy.text('text.view_administrator_accounts_110f2d1b'),
        description: AppCopy.text(
          'text.read_hospital_admin_and_system_auditor_accounts_58d16b84',
        ),
        area: 'Administrator accounts',
        icon: Icons.manage_accounts_outlined,
      ),
      AdminCapabilities.platformAdminAccountsManage: AdminCapabilityInfo(
        label: AppCopy.text('text.manage_administrator_accounts_cf44ab65'),
        description: AppCopy.text(
          'text.invite_update_suspend_restore_or_reset_mfa_for_a_b65bac50',
        ),
        area: 'Administrator accounts',
        icon: Icons.manage_accounts_outlined,
      ),
      AdminCapabilities.platformRolePolicyRead: AdminCapabilityInfo(
        label: AppCopy.text('text.view_access_policies_b1ad7ac4'),
        description: AppCopy.text(
          'text.read_fixed_administrator_policies_and_their_hist_8b06d9d5',
        ),
        area: 'Access control',
        icon: Icons.admin_panel_settings_outlined,
      ),
      AdminCapabilities.platformRolePolicyManage: AdminCapabilityInfo(
        label: AppCopy.text('text.manage_access_policies_ac9e36ee'),
        description: AppCopy.text(
          'text.update_or_restore_editable_administrator_policie_9a0790e8',
        ),
        area: 'Access control',
        icon: Icons.admin_panel_settings_outlined,
      ),
      AdminCapabilities.platformAuditRead: AdminCapabilityInfo(
        label: AppCopy.text('text.view_global_audit_49a978f0'),
        description: AppCopy.text(
          'text.read_global_operational_audit_events_a6389d86',
        ),
        area: 'Oversight',
        icon: Icons.history_outlined,
      ),
      AdminCapabilities.platformAnalyticsRead: AdminCapabilityInfo(
        label: AppCopy.text('text.view_global_analytics_10ea9a43'),
        description: AppCopy.text(
          'text.read_global_non_clinical_operational_analytics_182c74af',
        ),
        area: 'Oversight',
        icon: Icons.analytics_outlined,
      ),
      AdminCapabilities.platformBillingRead: AdminCapabilityInfo(
        label: AppCopy.text('text.view_platform_billing_dd75b258'),
        description: AppCopy.text(
          'text.read_platform_billing_and_invoices_bcc9d37c',
        ),
        area: 'Billing',
        icon: Icons.receipt_long_outlined,
      ),
      AdminCapabilities.platformBillingManage: AdminCapabilityInfo(
        label: AppCopy.text('text.manage_platform_billing_b69f3c4a'),
        description: AppCopy.text(
          'text.generate_invoices_and_run_platform_billing_opera_fc1f16ae',
        ),
        area: 'Billing',
        icon: Icons.receipt_long_outlined,
      ),
      AdminCapabilities.platformSystemConfigRead: AdminCapabilityInfo(
        label: AppCopy.text('text.view_platform_configuration_d4be58e5'),
        description: AppCopy.text(
          'text.read_global_runtime_configuration_632557b4',
        ),
        area: 'Platform',
        icon: Icons.tune_outlined,
      ),
      AdminCapabilities.platformSystemConfigManage: AdminCapabilityInfo(
        label: AppCopy.text('text.manage_platform_configuration_9cade703'),
        description: AppCopy.text(
          'text.change_global_runtime_configuration_2cd378bc',
        ),
        area: 'Platform',
        icon: Icons.tune_outlined,
      ),
      AdminCapabilities.platformSystemHealthRead: AdminCapabilityInfo(
        label: AppCopy.text('text.view_platform_health_b1b042bb'),
        description: AppCopy.text(
          'text.read_global_service_and_dependency_health_c16dbddb',
        ),
        area: 'Platform',
        icon: Icons.monitor_heart_outlined,
      ),
      AdminCapabilities.platformNotificationsBroadcast: AdminCapabilityInfo(
        label: AppCopy.text('text.broadcast_globally_47f687dc'),
        description: AppCopy.text(
          'text.send_a_global_administrative_notification_95a6646c',
        ),
        area: 'Communications',
        icon: Icons.campaign_outlined,
      ),
      AdminCapabilities.tenantDashboardRead: AdminCapabilityInfo(
        label: AppCopy.text('text.view_hospital_dashboard_2fbdec7a'),
        description: AppCopy.text(
          'text.read_the_hospital_scoped_operational_dashboard_b86da3ab',
        ),
        area: 'Hospital operations',
        icon: Icons.dashboard_outlined,
      ),
      AdminCapabilities.tenantDoctorsRead: AdminCapabilityInfo(
        label: AppCopy.text('text.view_doctors_8b522df8'),
        description: AppCopy.text(
          'text.list_doctor_accounts_in_the_assigned_hospital_4c4b7248',
        ),
        area: 'Hospital accounts',
        icon: Icons.medical_services_outlined,
      ),
      AdminCapabilities.tenantDoctorsManage: AdminCapabilityInfo(
        label: AppCopy.text('text.manage_doctors_78c1e2f2'),
        description: AppCopy.text(
          'text.create_and_update_non_clinical_doctor_account_da_1c1bc172',
        ),
        area: 'Hospital accounts',
        icon: Icons.medical_services_outlined,
      ),
      AdminCapabilities.tenantPatientsRead: AdminCapabilityInfo(
        label: AppCopy.text('text.view_patients_17c8ffc6'),
        description: AppCopy.text(
          'text.list_patient_accounts_in_the_assigned_hospital_8596042c',
        ),
        area: 'Hospital accounts',
        icon: Icons.people_outline,
      ),
      AdminCapabilities.tenantPatientsManage: AdminCapabilityInfo(
        label: AppCopy.text('text.manage_patients_c82ab898'),
        description: AppCopy.text(
          'text.create_and_update_non_clinical_patient_account_d_bac214c4',
        ),
        area: 'Hospital accounts',
        icon: Icons.people_outline,
      ),
      AdminCapabilities.tenantPatientsAssign: AdminCapabilityInfo(
        label: AppCopy.text('text.assign_patients_8a65c092'),
        description: AppCopy.text(
          'text.assign_patients_to_eligible_doctors_in_the_same__aac28622',
        ),
        area: 'Hospital accounts',
        icon: Icons.assignment_ind_outlined,
      ),
      AdminCapabilities.tenantAccountsStatusManage: AdminCapabilityInfo(
        label: AppCopy.text('text.manage_account_status_5045d721'),
        description: AppCopy.text(
          'text.suspend_or_restore_eligible_doctor_and_patient_a_24f5c0f8',
        ),
        area: 'Hospital accounts',
        icon: Icons.toggle_on_outlined,
      ),
      AdminCapabilities.tenantCredentialsReset: AdminCapabilityInfo(
        label: AppCopy.text('text.reset_credentials_29b17a6'),
        description: AppCopy.text(
          'text.reset_doctor_or_patient_credentials_in_the_hospi_b50c0ac9',
        ),
        area: 'Hospital accounts',
        icon: Icons.password_outlined,
      ),
      AdminCapabilities.tenantAuditRead: AdminCapabilityInfo(
        label: AppCopy.text('text.view_hospital_audit_32aec645'),
        description: AppCopy.text(
          'text.read_audit_events_for_the_assigned_hospital_9ef41e4d',
        ),
        area: 'Oversight',
        icon: Icons.history_outlined,
      ),
      AdminCapabilities.tenantAnalyticsRead: AdminCapabilityInfo(
        label: AppCopy.text('text.view_hospital_analytics_60e04852'),
        description: AppCopy.text(
          'text.read_non_clinical_analytics_for_the_assigned_hos_d064d3e0',
        ),
        area: 'Oversight',
        icon: Icons.analytics_outlined,
      ),
      AdminCapabilities.tenantBillingRead: AdminCapabilityInfo(
        label: AppCopy.text('text.view_hospital_billing_90d06ac5'),
        description: AppCopy.text(
          'text.read_invoices_belonging_to_the_assigned_hospital_d2f25020',
        ),
        area: 'Billing',
        icon: Icons.receipt_long_outlined,
      ),
      AdminCapabilities.tenantBillingCheckout: AdminCapabilityInfo(
        label: AppCopy.text('text.start_invoice_checkout_866e9b24'),
        description: AppCopy.text(
          'text.start_checkout_for_an_eligible_hospital_invoice_f31a1d63',
        ),
        area: 'Billing',
        icon: Icons.payment_outlined,
      ),
      AdminCapabilities.tenantNotificationsBroadcast: AdminCapabilityInfo(
        label: AppCopy.text('text.broadcast_within_hospital_cfac54c7'),
        description: AppCopy.text(
          'text.send_notifications_to_eligible_hospital_users_cf80467d',
        ),
        area: 'Communications',
        icon: Icons.campaign_outlined,
      ),
      AdminCapabilities.tenantOperationsHealthRead: AdminCapabilityInfo(
        label: AppCopy.text('text.view_hospital_operations_health_f03c24ba'),
        description: AppCopy.text(
          'text.read_hospital_reminder_and_delivery_health_63df8640',
        ),
        area: 'Hospital operations',
        icon: Icons.health_and_safety_outlined,
      ),
    };

String adminRoleLabel(AdminRole role) => switch (role) {
  AdminRole.appAdmin => 'Application Admin',
  AdminRole.hospitalAdmin => 'Hospital Admin',
  AdminRole.auditor => 'System Auditor',
};

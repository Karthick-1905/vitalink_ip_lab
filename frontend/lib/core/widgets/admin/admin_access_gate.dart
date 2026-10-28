import 'package:frontend/core/config/app_properties.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/admin/admin_access_scope.dart';
import 'package:frontend/features/admin/models/admin_access_model.dart';

class AdminAccessGate extends StatelessWidget {
  const AdminAccessGate({
    super.key,
    required this.builder,
    this.anyCapabilities = const <String>[],
    this.roles = const <AdminRole>{},
    this.scope,
    this.deniedTitle,
    this.deniedMessage,
  });

  final WidgetBuilder builder;
  final List<String> anyCapabilities;
  final Set<AdminRole> roles;
  final AdminScope? scope;
  final String? deniedTitle;
  final String? deniedMessage;

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final controller = AdminAccessScope.maybeOf(context);
    if (controller == null) {
      return AccessDeniedState(
        title:
            deniedTitle ??
            AppCopy.text('text.administrator_access_unavailable_30d06fa2'),
        message:
            deniedMessage ??
            AppCopy.text(
              'text.this_page_must_be_opened_from_the_administrator__f51217b3',
            ),
      );
    }

    final access = controller.access;
    if (access == null) {
      if (controller.isLoading || !controller.hasLoaded) {
        return Center(
          child: Semantics(
            label: AppCopy.text(
              'text.loading_administrator_permissions_6fe12216',
            ),
            child: CircularProgressIndicator(),
          ),
        );
      }
      return AccessDeniedState(
        title: AppCopy.text(
          'text.could_not_verify_administrator_access_ff0520f9',
        ),
        message: AppCopy.text(
          'text.vitalink_could_not_load_your_current_permissions_2b649673',
        ),
        actionLabel: AppCopy.text('text.try_again_213e90fa'),
        onAction: controller.refresh,
      );
    }

    final capabilityAllowed =
        anyCapabilities.isEmpty || access.canAny(anyCapabilities);
    final roleAllowed = roles.isEmpty || roles.contains(access.role);
    final scopeAllowed = scope == null || access.scope == scope;
    if (!capabilityAllowed || !roleAllowed || !scopeAllowed) {
      return AccessDeniedState(
        title:
            deniedTitle ??
            AppCopy.text('text.you_do_not_have_access_to_this_page_4dc78fa6'),
        message:
            deniedMessage ??
            AppCopy.text(
              'text.your_current_administrator_policy_does_not_inclu_63c48c24',
            ),
      );
    }

    return builder(context);
  }
}

class AccessDeniedState extends StatelessWidget {
  const AccessDeniedState({
    super.key,
    this.title = 'Access not available',
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          container: true,
          label: "${(title).toString()}. ${(message).toString()}",
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => onAction!(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(actionLabel!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminReadOnlyBanner extends StatelessWidget {
  const AdminReadOnlyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: AppCopy.text(
        'text.system_auditor_read_only_mode_you_can_review_per_5c1ab2fa',
      ),
      child: Material(
        color: theme.colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppCopy.text(
                    'text.system_auditor_read_only_mode_you_can_review_per_b168f8b6',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

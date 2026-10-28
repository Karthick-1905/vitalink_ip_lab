import 'package:frontend/core/config/app_properties.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/core/query/admin_query_keys.dart';
import 'package:frontend/core/widgets/admin/admin_scaffold.dart';
import 'package:frontend/core/widgets/common/api_error_state.dart';
import 'package:frontend/features/admin/data/admin_repository.dart';
import 'package:frontend/features/admin/models/audit_log_model.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  final AdminRepository _repo = AppDependencies.adminRepository;
  int _page = 1;
  String? _actionFilter;
  String? _successFilter;
  String? _startDate;
  String? _endDate;
  int _refreshKey = 0;

  void _refresh() => setState(() => _refreshKey++);

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return UseQuery<Map<String, dynamic>>(
      options: QueryOptions<Map<String, dynamic>>(
        queryKey: AdminQueryKeys.auditLogs(
          page: _page,
          actionFilter: _actionFilter ?? '',
          successFilter: _successFilter ?? '',
          startDate: _startDate ?? '',
          endDate: _endDate ?? '',
          refreshKey: _refreshKey,
        ),
        queryFn: () => _repo.getAuditLogs(
          page: _page,
          action: _actionFilter,
          success: _successFilter,
          startDate: _startDate,
          endDate: _endDate,
        ),
      ),
      builder: (context, query) {
        final dataMap = query.data ?? {};
        final logsList = dataMap['logs'] as List? ?? [];
        final pagination = dataMap['pagination'] as Map<String, dynamic>? ?? {};
        final total = pagination['total'] as int? ?? logsList.length;
        final pageSize = pagination['limit'] as int? ?? 50;
        final totalPages =
            pagination['pages'] as int? ?? (total / pageSize).ceil();

        final logs = logsList
            .map((e) => AuditLogModel.fromJson(e as Map<String, dynamic>))
            .toList();
        final showPageScaffold = !AdminScaffold.usesShellAppBar(context);
        final content = Column(
          children: [
            if (!showPageScaffold)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppCopy.text('text.system_audit_logs_2ffd9a72'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _refresh,
                      tooltip: AppCopy.text('text.refresh_815aad4'),
                    ),
                  ],
                ),
              ),
            // Filters
            _FilterBar(
              actionFilter: _actionFilter,
              successFilter: _successFilter,
              startDate: _startDate,
              endDate: _endDate,
              onActionChanged: (v) => setState(() {
                _actionFilter = v;
                _page = 1;
              }),
              onSuccessChanged: (v) => setState(() {
                _successFilter = v;
                _page = 1;
              }),
              onDateRangeChanged: (s, e) => setState(() {
                _startDate = s;
                _endDate = e;
                _page = 1;
              }),
              onClear: () => setState(() {
                _actionFilter = null;
                _successFilter = null;
                _startDate = null;
                _endDate = null;
                _page = 1;
              }),
            ),

            // Active filter chips
            if (_actionFilter != null ||
                _successFilter != null ||
                _startDate != null)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    if (_actionFilter != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text(_actionFilter!.replaceAll('_', ' ')),
                          onDeleted: () => setState(() {
                            _actionFilter = null;
                            _page = 1;
                          }),
                        ),
                      ),
                    if (_successFilter != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text(
                            _successFilter == 'true'
                                ? AppCopy.text('text.success_6d8303b0')
                                : AppCopy.text('text.failed_5579c3d4'),
                          ),
                          backgroundColor: _successFilter == 'true'
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          onDeleted: () => setState(() {
                            _successFilter = null;
                            _page = 1;
                          }),
                        ),
                      ),
                    if (_startDate != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text('$_startDate - ${_endDate ?? 'now'}'),
                          onDeleted: () => setState(() {
                            _startDate = null;
                            _endDate = null;
                            _page = 1;
                          }),
                        ),
                      ),
                  ],
                ),
              ),

            // Content
            Expanded(
              child: query.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : query.isError
                  ? ApiErrorState(error: query.error, onRetry: _refresh)
                  : logs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            AppCopy.text('text.no_audit_logs_found_54833b7c'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: logs.length,
                      itemBuilder: (context, index) =>
                          _AuditLogTile(log: logs[index]),
                    ),
            ),

            // Pagination
            if (totalPages > 1)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: _page > 1
                          ? () => setState(() => _page--)
                          : null,
                    ),
                    Text(
                      AppCopy.text(
                        'text.page_value1_of_value2_bd90d60a',
                        arguments: {
                          'value1': (_page).toString(),
                          'value2': (totalPages > 0 ? totalPages : 1)
                              .toString(),
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: _page < totalPages
                          ? () => setState(() => _page++)
                          : null,
                    ),
                  ],
                ),
              ),
          ],
        );

        if (!showPageScaffold) {
          return content;
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(AppCopy.text('text.system_audit_logs_2ffd9a72')),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _refresh,
              ),
            ],
          ),
          body: content,
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String? actionFilter, successFilter, startDate, endDate;
  final ValueChanged<String?> onActionChanged, onSuccessChanged;
  final void Function(String?, String?) onDateRangeChanged;
  final VoidCallback onClear;

  const _FilterBar({
    required this.actionFilter,
    required this.successFilter,
    required this.startDate,
    required this.endDate,
    required this.onActionChanged,
    required this.onSuccessChanged,
    required this.onDateRangeChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        title: Text(AppCopy.text('text.filters_b3aa6ec')),
        leading: const Icon(Icons.filter_list_rounded),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: AppCopy.text('text.action_a77a91f'),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  initialValue: actionFilter,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(AppCopy.text('text.all_actions_809a2cf7')),
                    ),
                    ...AuditAction.values.map(
                      (e) => DropdownMenuItem(
                        value: e.value,
                        child: Text(e.label),
                      ),
                    ),
                  ],
                  onChanged: onActionChanged,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: AppCopy.text('text.status_5ef20f'),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  initialValue: successFilter,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(AppCopy.text('text.all_status_96e23776')),
                    ),
                    DropdownMenuItem(
                      value: 'true',
                      child: Text(AppCopy.text('text.success_6d8303b0')),
                    ),
                    DropdownMenuItem(
                      value: 'false',
                      child: Text(AppCopy.text('text.failed_5579c3d4')),
                    ),
                  ],
                  onChanged: onSuccessChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.date_range_rounded),
                  label: Text(
                    startDate == null
                        ? AppCopy.text('text.select_date_range_6fbb8256')
                        : '$startDate - ${endDate ?? "now"}',
                  ),
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      onDateRangeChanged(
                        picked.start.toIso8601String().split('T').first,
                        picked.end.toIso8601String().split('T').first,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                icon: const Icon(Icons.clear_all_rounded),
                label: Text(AppCopy.text('text.clear_all_de7f94e5')),
                onPressed: onClear,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  final AuditLogModel log;
  const _AuditLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    final theme = Theme.of(context);
    final actionStr = log.action;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        isThreeLine: true,
        leading: CircleAvatar(
          backgroundColor: _actionColor(actionStr).withValues(alpha: 0.1),
          child: Icon(
            _actionIcon(actionStr),
            color: _actionColor(actionStr),
            size: 20,
          ),
        ),
        title: Text(
          actionStr.replaceAll('_', ' '),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              log.description.isEmpty
                  ? AppCopy.text('text.no_description_9c7619b0')
                  : log.description,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(log.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const Spacer(),
                if (!log.success)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      AppCopy.text('text.failed_d7e8fab4'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '--';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _actionColor(String action) {
    if (action.contains('CREATE') || action.contains('REGISTER')) {
      return Colors.green;
    }
    if (action.contains('UPDATE')) return Colors.blue;
    if (action.contains('DELETE') || action.contains('DEACTIVATE')) {
      return Colors.red;
    }
    if (action.contains('LOGIN') || action.contains('LOGOUT')) {
      return Colors.purple;
    }
    if (action.contains('PASSWORD')) return Colors.orange;
    return Colors.grey;
  }

  IconData _actionIcon(String action) {
    if (action.contains('LOGIN')) return Icons.login_rounded;
    if (action.contains('LOGOUT')) return Icons.logout_rounded;
    if (action.contains('CREATE') || action.contains('REGISTER')) {
      return Icons.add_circle_outline_rounded;
    }
    if (action.contains('UPDATE')) return Icons.edit_note_rounded;
    if (action.contains('DELETE') || action.contains('DEACTIVATE')) {
      return Icons.remove_circle_outline_rounded;
    }
    if (action.contains('PASSWORD')) return Icons.lock_reset_rounded;
    return Icons.info_outline_rounded;
  }
}

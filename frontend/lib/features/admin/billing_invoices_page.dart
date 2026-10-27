import 'package:frontend/core/config/app_properties.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/core/query/admin_query_keys.dart';
import 'package:frontend/core/widgets/admin/admin_access_gate.dart';
import 'package:frontend/core/widgets/admin/admin_access_scope.dart';
import 'package:frontend/features/admin/admin_capabilities.dart';
import 'package:frontend/features/admin/admin_console_components.dart';

class BillingInvoicesPage extends StatefulWidget {
  const BillingInvoicesPage({super.key});

  @override
  State<BillingInvoicesPage> createState() => _BillingInvoicesPageState();
}

class _BillingInvoicesPageState extends State<BillingInvoicesPage> {
  final _repo = AppDependencies.adminRepository;
  final _search = TextEditingController();
  int _refreshKey = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _refresh() => setState(() => _refreshKey++);

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    return AdminAccessGate(
      anyCapabilities: AdminCapabilities.billingRead,
      builder: (context) {
        final canGenerate = AdminAccessScope.can(
          context,
          AdminCapabilities.platformBillingManage,
        );
        final canCheckout = AdminAccessScope.can(
          context,
          AdminCapabilities.tenantBillingCheckout,
        );
        return UseQuery<Map<String, dynamic>>(
          options: QueryOptions<Map<String, dynamic>>(
            queryKey: AdminQueryKeys.invoices(refreshKey: _refreshKey),
            queryFn: _repo.getInvoices,
          ),
          builder: (context, query) {
            final all = query.data?['invoices'] as List? ?? const [];
            final q = _search.text.toLowerCase();
            final invoices = all.where((item) {
              final invoice = item as Map<String, dynamic>;
              return "${(invoice['id']).toString()} ${(invoice['hospitalName']).toString()} ${(invoice['plan']).toString()}"
                  .toLowerCase()
                  .contains(q);
            }).toList();
            final content = AdminListShell(
              title: AppCopy.text('text.billing_invoices_940223a6'),
              subtitle: canGenerate || canCheckout
                  ? AppCopy.text(
                      'text.review_invoices_and_use_only_the_billing_actions_1c831526',
                    )
                  : AppCopy.text('text.read_only_invoice_access_dc170d49'),
              searchController: _search,
              searchHint: AppCopy.text('text.search_invoices_9793a623'),
              onSearch: () => setState(() {}),
              actions: [
                if (canGenerate)
                  FilledButton.icon(
                    onPressed: _confirmInvoiceGeneration,
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: Text(AppCopy.text('text.generate_c75562b2')),
                  ),
              ],
              child: AdminQueryBody<Map<String, dynamic>>(
                query: query,
                emptyIcon: Icons.receipt_long_outlined,
                // Query-level empty: no invoices from the server at all.
                emptyText: 'No invoices found',
                isEmpty: all.isEmpty,
                child: invoices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              AppCopy.text(
                                'text.no_invoices_match_your_search_46af4e86',
                              ),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: invoices.length,
                        itemBuilder: (context, index) {
                          final invoice =
                              invoices[index] as Map<String, dynamic>;
                          final id = '${invoice['id']}';
                          final status = '${invoice['status'] ?? 'Pending'}';
                          return AdminRecordCard(
                            icon: Icons.receipt_rounded,
                            title: id,
                            badge: status,
                            details: [
                              AdminDetail(
                                Icons.local_hospital_outlined,
                                '${invoice['hospitalName'] ?? invoice['hospital'] ?? '--'}',
                              ),
                              AdminDetail(
                                Icons.workspace_premium_outlined,
                                '${invoice['plan'] ?? '--'}',
                              ),
                              AdminDetail(
                                Icons.currency_rupee_rounded,
                                '${invoice['amount'] ?? 0}',
                              ),
                              AdminDetail(
                                Icons.event_outlined,
                                'Due ${formatAdminDate(invoice['due'])}',
                              ),
                            ],
                            menu: canCheckout
                                ? [
                                    PopupMenuItem(
                                      enabled: status != 'Paid',
                                      value: 'checkout',
                                      child: Text(
                                        AppCopy.text(
                                          'text.create_checkout_8080183',
                                        ),
                                      ),
                                      onTap: () => Future.microtask(
                                        () => _startInvoiceCheckout(id),
                                      ),
                                    ),
                                  ]
                                : const [],
                          );
                        },
                      ),
              ),
            );
            return adminPageScaffold(context, 'Billing', content);
          },
        );
      },
    );
  }

  Future<void> _confirmInvoiceGeneration() async {
    final period = TextEditingController(
      text:
          "${(DateTime.now().year).toString()}-${(DateTime.now().month.toString().padLeft(2, '0')).toString()}",
    );
    final billingPeriod = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppCopy.text('text.generate_invoices_3a71a10f')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppCopy.text(
                'text.this_creates_invoices_for_every_active_hospital__fd2e08c',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: period,
              decoration: InputDecoration(
                labelText: AppCopy.text('text.billing_period_yyyy_mm_6f4d4df1'),
                hintText: '2026-07',
              ),
              keyboardType: TextInputType.datetime,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppCopy.text('text.cancel_35afca3b')),
          ),
          FilledButton(
            onPressed: () {
              final value = period.text.trim();
              if (RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value)) {
                Navigator.pop(dialogContext, value);
              } else {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppCopy.text(
                        'text.enter_a_billing_period_as_yyyy_mm_cbcf052b',
                      ),
                    ),
                  ),
                );
              }
            },
            child: Text(AppCopy.text('text.generate_c75562b2')),
          ),
        ],
      ),
    );
    period.dispose();
    if (billingPeriod == null || !mounted) return;

    try {
      final result = await _repo.generateInvoices(billingPeriod: billingPeriod);
      if (!mounted) return;
      _refresh();
      final created = result['created'] as num? ?? 0;
      final existing = result['already_existing'] as num? ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppCopy.text(
              'text.value1_created_value2_already_existed_for_value3_62a2236c',
              arguments: {
                'value1': (created).toString(),
                'value2': (existing).toString(),
                'value3': (billingPeriod).toString(),
              },
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) showAdminError(context, e);
    }
  }

  Future<void> _startInvoiceCheckout(String invoiceId) async {
    try {
      final result = await _repo.createInvoiceCheckout(invoiceId);
      final checkoutUrl = result['checkout_url'] as String?;
      final uri = checkoutUrl == null ? null : Uri.tryParse(checkoutUrl);
      final isSafeScheme =
          uri != null &&
          (uri.scheme == 'https' ||
              (uri.scheme == 'http' &&
                  (uri.host == 'localhost' || uri.host == '127.0.0.1')));
      if (!isSafeScheme ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Unable to open the configured payment checkout.');
      }
    } catch (e) {
      if (mounted) showAdminError(context, e);
    }
  }
}

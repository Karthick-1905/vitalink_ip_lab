import 'package:flutter/material.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/core/query/payment_query_keys.dart';
import 'package:intl/intl.dart';

class PatientTransactionHistoryPage extends StatefulWidget {
  final bool embedInShell;
  final ValueChanged<int>? onTabChanged;

  const PatientTransactionHistoryPage({
    super.key,
    this.embedInShell = false,
    this.onTabChanged,
  });

  @override
  State<PatientTransactionHistoryPage> createState() =>
      _PatientTransactionHistoryPageState();
}

class _PatientTransactionHistoryPageState
    extends State<PatientTransactionHistoryPage> {
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  Widget build(BuildContext context) {
    return UseQuery<Map<String, dynamic>>(
      options: QueryOptions<Map<String, dynamic>>(
        queryKey: PaymentQueryKeys.transactionsPaginated(_currentPage, _itemsPerPage),
        queryFn: () async {
          return await AppDependencies.paymentRepository.listTransactions(
            page: _currentPage,
            limit: _itemsPerPage,
          );
        },
        staleTime: const Duration(minutes: 5),
      ),
      builder: (context, query) {
        return _buildPageContainer(
          body: query.isLoading
              ? const Center(child: CircularProgressIndicator())
              : query.isError
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Error: ${query.error}'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => query.refetch(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _buildTransactionsList(query.data ?? {}),
        );
      },
    );
  }

  Widget _buildTransactionsList(Map<String, dynamic> data) {
    final transactions =
        (data['transactions'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final pagination =
        data['pagination'] as Map<String, dynamic>? ?? {};

    if (transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No transactions yet',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ...transactions.map((transaction) =>
                _buildTransactionCard(transaction)),
            const SizedBox(height: 24),
            if (pagination.isNotEmpty) _buildPaginationControls(pagination),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final amount = transaction['amount'] ?? 0;
    final type = transaction['type'] ?? 'Unknown';
    final date = transaction['date'] ?? transaction['createdAt'] ?? DateTime.now();
    final status = transaction['status'] ?? 'completed';

    DateTime parsedDate;
    if (date is String) {
      parsedDate = DateTime.tryParse(date) ?? DateTime.now();
    } else if (date is DateTime) {
      parsedDate = date;
    } else {
      parsedDate = DateTime.now();
    }

    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(parsedDate);
    final isCredit = type.toLowerCase().contains('credit') ||
        type.toLowerCase().contains('purchase');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: status.toLowerCase() == 'completed'
                        ? Colors.green[100]
                        : Colors.yellow[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: status.toLowerCase() == 'completed'
                          ? Colors.green[700]
                          : Colors.yellow[700],
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '${isCredit ? '+' : '-'}$amount',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isCredit ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls(Map<String, dynamic> pagination) {
    final total = pagination['total'] as int? ?? 0;
    final limit = pagination['limit'] as int? ?? 10;
    final totalPages = (total / limit).ceil();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _currentPage > 1
              ? () => setState(() => _currentPage--)
              : null,
          child: const Text('Previous'),
        ),
        const SizedBox(width: 12),
        Text(
          'Page $_currentPage of $totalPages',
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _currentPage < totalPages
              ? () => setState(() => _currentPage++)
              : null,
          child: const Text('Next'),
        ),
      ],
    );
  }

  Widget _buildPageContainer({required Widget body}) {
    if (widget.embedInShell) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        elevation: 0,
      ),
      body: body,
    );
  }
}

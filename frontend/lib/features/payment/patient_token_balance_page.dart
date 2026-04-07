import 'package:flutter/material.dart';
import 'package:flutter_tanstack_query/flutter_tanstack_query.dart';
import 'package:frontend/core/di/app_dependencies.dart';
import 'package:frontend/core/query/payment_query_keys.dart';
import 'package:frontend/features/payment/widgets/token_widgets.dart';

class PatientTokenBalancePage extends StatefulWidget {
  final bool embedInShell;
  final ValueChanged<int>? onTabChanged;

  const PatientTokenBalancePage({
    super.key,
    this.embedInShell = false,
    this.onTabChanged,
  });

  @override
  State<PatientTokenBalancePage> createState() =>
      _PatientTokenBalancePageState();
}

class _PatientTokenBalancePageState extends State<PatientTokenBalancePage> {

  @override
  Widget build(BuildContext context) {
    return UseQuery<Map<String, dynamic>>(
      options: QueryOptions<Map<String, dynamic>>(
        queryKey: PaymentQueryKeys.tokenBalance(),
        queryFn: () async {
          return await AppDependencies.paymentRepository.getTokenBalance();
        },
        staleTime: const Duration(minutes: 5),
      ),
      builder: (context, query) {
        return _buildPageContainer(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Token Balance Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Token Balance',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (query.isLoading)
                            const CircularProgressIndicator()
                          else if (query.isError)
                            Column(
                              children: [
                                Text(
                                  'Error: ${query.error}',
                                  style: const TextStyle(color: Colors.red),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () => query.refetch(),
                                  child: const Text('Retry'),
                                ),
                              ],
                            )
                          else
                            Column(
                              children: [
                                Text(
                                  '${(query.data?['balance'] as num? ?? 0).toInt()} Tokens',
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0084FF),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TokenProgressBarWidget(
                                  currentTokens: (query.data?['balance'] as num? ?? 0).toInt(),
                                  maxTokens: (query.data?['max_tokens'] as num? ?? 200).toInt(),
                                  showPercentage: true,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Token Plans Section
                  const Text(
                    'Purchase Tokens',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Token Plans
                  _buildTokenPlanCard(
                    planId: 'plan_100',
                    planName: 'Basic Plan',
                    tokens: 100,
                    price: '₹49',
                  ),
                  const SizedBox(height: 12),
                  _buildTokenPlanCard(
                    planId: 'plan_200',
                    planName: 'Premium Plan',
                    tokens: 200,
                    price: '₹99',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTokenPlanCard({
    required String planId,
    required String planName,
    required int tokens,
    required String price,
  }) {
    return UseMutation<Map<String, dynamic>, String>(
      options: MutationOptions<Map<String, dynamic>, String>(
        mutationFn: (variables) async {
          return await AppDependencies.paymentRepository.createPaymentOrder(
            planId: variables,
          );
        },
        onSuccess: (data, variables) {
          final orderId = data['id'] ?? data['order_id'] ?? 'Order';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Payment order created!',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Order ID: $orderId',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              duration: const Duration(seconds: 4),
            ),
          );
          // Invalidate balance query
          final queryClient = QueryClientProvider.of(context);
          queryClient.invalidateQueries(PaymentQueryKeys.tokenBalance());
        },
        onError: (error, variables) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Payment Failed',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    error.toString().split(':').last.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              backgroundColor: Colors.red.shade600,
              duration: const Duration(seconds: 4),
            ),
          );
        },
      ),
      builder: (context, mutation) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        planName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$tokens Tokens',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        price,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0084FF),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 80,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: mutation.isLoading
                              ? null
                              : () => mutation.mutate(planId),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                          ),
                          child: mutation.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('Buy', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageContainer({required Widget body}) {
    if (widget.embedInShell) {
      return Scaffold(
        body: body,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Token Balance'),
        elevation: 0,
      ),
      body: body,
    );
  }
}

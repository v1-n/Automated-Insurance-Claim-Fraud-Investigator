import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/policy_provider.dart';
import 'admin_create_plan_screen.dart';

class AdminPoliciesScreen extends StatefulWidget {
  const AdminPoliciesScreen({super.key});

  @override
  State<AdminPoliciesScreen> createState() => _AdminPoliciesScreenState();
}

class _AdminPoliciesScreenState extends State<AdminPoliciesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PolicyProvider>().fetchAvailablePlans();
    });
  }

  void _goToCreatePlan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminCreatePlanScreen()),
    ).then((_) {
      // Refresh list immediately when returning from create screen
      if (mounted) {
        context.read<PolicyProvider>().fetchAvailablePlans();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final policyProvider = context.watch<PolicyProvider>();
    final plans = policyProvider.availablePlans;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insurance Plans'),
      ),
      body: policyProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => context.read<PolicyProvider>().fetchAvailablePlans(),
              child: plans.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.policy_outlined, size: 70, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text(
                            'No Insurance Plans Found',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create master insurance plans to allow customer selection.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _goToCreatePlan,
                            icon: const Icon(Icons.add),
                            label: const Text('Create First Plan'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: plans.length,
                      itemBuilder: (context, index) {
                        final plan = plans[index];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        plan.planName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        plan.policyType
                                            .replaceAll('_', ' ')
                                            .toLowerCase()
                                            .split(' ')
                                            .map((w) => w.isNotEmpty
                                                ? '${w[0].toUpperCase()}${w.substring(1)}'
                                                : '')
                                            .join(' '),
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (plan.description.isNotEmpty) ...
                                  [
                                    const SizedBox(height: 6),
                                    Text(
                                      plan.description,
                                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                const Divider(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _InfoChip(
                                        icon: Icons.account_balance_wallet_outlined,
                                        label: 'Max IDV',
                                        value: '₹ ${plan.maxIdvCoverage.toStringAsFixed(0)}',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _InfoChip(
                                        icon: Icons.receipt_long_outlined,
                                        label: 'Annual Premium',
                                        value: '₹ ${plan.annualPremium.toStringAsFixed(0)}',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToCreatePlan,
        icon: const Icon(Icons.add),
        label: const Text('New Plan'),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

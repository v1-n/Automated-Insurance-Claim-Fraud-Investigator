import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/policy_provider.dart';
import 'buy_policy_screen.dart';

class MyPoliciesScreen extends StatefulWidget {
  const MyPoliciesScreen({super.key});

  @override
  State<MyPoliciesScreen> createState() => _MyPoliciesScreenState();
}

class _MyPoliciesScreenState extends State<MyPoliciesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PolicyProvider>().fetchMyPolicies();
    });
  }

  @override
  Widget build(BuildContext context) {
    final policyProvider = context.watch<PolicyProvider>();
    final policies = policyProvider.myPolicies;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vehicle Policies'),
        centerTitle: true,
      ),
      body: policyProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => context.read<PolicyProvider>().fetchMyPolicies(),
              child: policies.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_outlined, size: 70, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text(
                            'No Active Policies Found',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You do not have any active insurance policies yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const BuyPolicyScreen()),
                              ).then((_) {
                                if (context.mounted) {
                                  context.read<PolicyProvider>().fetchMyPolicies();
                                }
                              });
                            },
                            icon: const Icon(Icons.shield_outlined),
                            label: const Text('Explore & Buy Policy'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: policies.length,
                      itemBuilder: (context, index) {
                        final policy = policies[index];
                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        policy.planName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        policy.policyStatus,
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                _buildInfoRow(Icons.confirmation_number_outlined, 'Policy No', policy.policyNumber),
                                const SizedBox(height: 8),
                                _buildInfoRow(Icons.directions_car_outlined, 'Vehicle Reg', policy.vehicleNumber),
                                const SizedBox(height: 8),
                                _buildInfoRow(Icons.car_repair_outlined, 'Make/Model', policy.vehicleMakeModel),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  Icons.account_balance_wallet_outlined,
                                  'Insured Value (IDV)',
                                  '₹ ${policy.insuredDeclaredValue.toStringAsFixed(2)}',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BuyPolicyScreen()),
          ).then((_) {
            if (context.mounted) {
              context.read<PolicyProvider>().fetchMyPolicies();
            }
          });
        },
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Buy / Apply Policy'),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

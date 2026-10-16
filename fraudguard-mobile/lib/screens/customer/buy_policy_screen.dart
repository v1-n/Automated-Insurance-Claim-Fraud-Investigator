import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/policy_plan_model.dart';
import '../../providers/policy_provider.dart';

class BuyPolicyScreen extends StatefulWidget {
  const BuyPolicyScreen({super.key});

  @override
  State<BuyPolicyScreen> createState() => _BuyPolicyScreenState();
}

class _BuyPolicyScreenState extends State<BuyPolicyScreen> {
  PolicyPlanModel? _selectedPlan;
  final _formKey = GlobalKey<FormState>();
  final _vehicleNumberController = TextEditingController();
  final _vehicleMakeModelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PolicyProvider>();
      provider.fetchAvailablePlans();
      provider.fetchMyPolicies();
    });
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _vehicleMakeModelController.dispose();
    super.dispose();
  }

  void _submitSelection() async {
    if (_selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an insurance plan first')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final policyProvider = context.read<PolicyProvider>();
    final result = await policyProvider.selectAndActivatePolicy(
      planId: _selectedPlan!.planId,
      vehicleNumber: _vehicleNumberController.text.trim().toUpperCase(),
      vehicleMakeModel: _vehicleMakeModelController.text.trim(),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Policy ${result.policyNumber} activated successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final policyProvider = context.watch<PolicyProvider>();
    final plans = policyProvider.availablePlans;
    final myPolicies = policyProvider.myPolicies;

    // Build set of already-purchased plan names to prevent re-buying
    final purchasedPlanNames = myPolicies
        .where((p) => p.policyStatus == 'ACTIVE')
        .map((p) => p.planName)
        .toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Vehicle Policy'),
      ),
      body: policyProvider.isLoading && plans.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1. Choose Insurance Package',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    plans.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.amber),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text('No active plans available from Admin yet.'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: plans.length,
                            itemBuilder: (context, index) {
                              final plan = plans[index];
                              final isSelected = _selectedPlan?.planId == plan.planId;
                              final alreadyPurchased = purchasedPlanNames.contains(plan.planName);
                              return Card(
                                color: alreadyPurchased
                                    ? Colors.grey.shade100
                                    : isSelected
                                        ? Theme.of(context).primaryColor.withOpacity(0.08)
                                        : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: alreadyPurchased
                                        ? Colors.grey.shade400
                                        : isSelected
                                            ? Theme.of(context).primaryColor
                                            : Colors.grey.shade300,
                                    width: isSelected && !alreadyPurchased ? 2 : 1,
                                  ),
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                child: RadioListTile<PolicyPlanModel>(
                                  value: plan,
                                  groupValue: _selectedPlan,
                                  onChanged: alreadyPurchased
                                      ? null
                                      : (val) {
                                          setState(() => _selectedPlan = val);
                                        },
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          plan.planName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: alreadyPurchased ? Colors.grey : null,
                                          ),
                                        ),
                                      ),
                                      if (alreadyPurchased)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            '✓ Purchased',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    'Max IDV: ₹ ${plan.maxIdvCoverage.toStringAsFixed(0)} • Premium: ₹ ${plan.annualPremium.toStringAsFixed(0)}/yr\n${plan.description}',
                                    style: TextStyle(
                                      color: alreadyPurchased ? Colors.grey : null,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                    const SizedBox(height: 24),
                    const Text(
                      '2. Enter Vehicle Details',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _vehicleNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Registration Number',
                        hintText: 'e.g. MH-12-AB-1234',
                        prefixIcon: Icon(Icons.confirmation_number_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter vehicle number' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _vehicleMakeModelController,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Make & Model',
                        hintText: 'e.g. Swift Dzire 2023',
                        prefixIcon: Icon(Icons.directions_car_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter vehicle make/model' : null,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: policyProvider.isLoading ? null : _submitSelection,
                        child: policyProvider.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text('Confirm & Activate Policy', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

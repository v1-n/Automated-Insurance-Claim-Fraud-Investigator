import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/policy_provider.dart';

class AdminCreatePlanScreen extends StatefulWidget {
  const AdminCreatePlanScreen({super.key});

  @override
  State<AdminCreatePlanScreen> createState() => _AdminCreatePlanScreenState();
}

class _AdminCreatePlanScreenState extends State<AdminCreatePlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _planNameController = TextEditingController();
  final _maxIdvController = TextEditingController();
  final _annualPremiumController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedPolicyType = 'MOTOR_COMPREHENSIVE';

  @override
  void dispose() {
    _planNameController.dispose();
    _maxIdvController.dispose();
    _annualPremiumController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submitPlan() async {
    if (!_formKey.currentState!.validate()) return;

    final policyProvider = context.read<PolicyProvider>();
    final result = await policyProvider.createPolicyPlan(
      planName: _planNameController.text.trim(),
      policyType: _selectedPolicyType,
      maxIdvCoverage: double.parse(_maxIdvController.text.trim()),
      annualPremium: double.parse(_annualPremiumController.text.trim()),
      description: _descriptionController.text.trim(),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Insurance Plan "${result.planName}" created successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final policyProvider = context.watch<PolicyProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Insurance Plan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _planNameController,
                decoration: const InputDecoration(
                  labelText: 'Plan Name',
                  hintText: 'e.g. Comprehensive Motor Shield',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter plan name' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPolicyType,
                decoration: const InputDecoration(
                  labelText: 'Policy Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'MOTOR_COMPREHENSIVE', child: Text('Motor Comprehensive')),
                  DropdownMenuItem(value: 'MOTOR_THIRD_PARTY', child: Text('Motor Third Party')),
                  DropdownMenuItem(value: 'MOTOR_ZERO_DEP', child: Text('Motor Zero Bumper Dep')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPolicyType = val);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _maxIdvController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Maximum IDV Coverage (₹)',
                  hintText: 'e.g. 500000',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || double.tryParse(val.trim()) == null ? 'Enter valid IDV' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _annualPremiumController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Annual Premium (₹)',
                  hintText: 'e.g. 8500',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || double.tryParse(val.trim()) == null ? 'Enter valid premium' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Plan Description',
                  hintText: 'Describe coverage details and features',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: policyProvider.isLoading ? null : _submitPlan,
                  child: policyProvider.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Create Plan', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

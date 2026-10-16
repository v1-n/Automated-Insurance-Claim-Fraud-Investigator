import 'package:flutter/material.dart';
import '../../models/investigator_workload_model.dart';
import '../../services/admin_service.dart';
import '../../theme/app_theme.dart';

class AdminWorkloadScreen extends StatefulWidget {
  const AdminWorkloadScreen({super.key});

  @override
  State<AdminWorkloadScreen> createState() => _AdminWorkloadScreenState();
}

class _AdminWorkloadScreenState extends State<AdminWorkloadScreen> {
  final AdminService _adminService = AdminService();

  List<InvestigatorWorkloadModel> _workloads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWorkload();
  }

  Future<void> _fetchWorkload() async {
    setState(() => _isLoading = true);
    try {
      final list = await _adminService.getInvestigatorsWorkload();
      setState(() {
        _workloads = list;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Investigator Capacity & Workload'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchWorkload,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _workloads.isEmpty
                ? const Center(child: Text('No active investigators registered.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _workloads.length,
                    itemBuilder: (context, idx) {
                      final item = _workloads[idx];
                      final isBusy = item.activeAssignedClaims >= 5;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppTheme.primaryBlue.withAlpha(40),
                                    child: Text(
                                      item.investigatorName[0].toUpperCase(),
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.investigatorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text(item.email, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (isBusy ? AppTheme.dangerRed : AppTheme.successGreen).withAlpha(40),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      isBusy ? 'HIGH LOAD' : 'AVAILABLE',
                                      style: TextStyle(
                                        color: isBusy ? AppTheme.dangerRed : AppTheme.successGreen,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatPill('Active Cases', '${item.activeAssignedClaims}', AppTheme.warningAmber),
                                  _buildStatPill('Completed Reviews', '${item.completedReviews}', AppTheme.successGreen),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildStatPill(String title, String val, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

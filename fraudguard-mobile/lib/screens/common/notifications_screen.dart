import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications & Alerts'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildNotificationItem(
            'Claim Approved',
            'Your claim #POL-100234 has been officially approved for disbursement.',
            '10 mins ago',
            Icons.check_circle_outline,
            AppTheme.successGreen,
          ),
          _buildNotificationItem(
            'Investigation Assigned',
            'Claim #POL-992014 was assigned to your review queue.',
            '1 hour ago',
            Icons.assignment_ind_outlined,
            AppTheme.primaryBlue,
          ),
          _buildNotificationItem(
            'High Risk Alert',
            'Fraud AI engine flagged a claim with 85% anomaly confidence.',
            '3 hours ago',
            Icons.warning_amber_rounded,
            AppTheme.dangerRed,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(String title, String body, String time, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: Icon(icon, color: color),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(time, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(body),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/investigator_claims_provider.dart';
import '../../providers/realtime_provider.dart';
import '../../theme/app_theme.dart';
import 'investigation_detail_screen.dart';

class InvestigatorDashboardScreen extends StatefulWidget {
  final VoidCallback? onSeeAll;
  const InvestigatorDashboardScreen({super.key, this.onSeeAll});

  @override
  State<InvestigatorDashboardScreen> createState() => _InvestigatorDashboardScreenState();
}

class _InvestigatorDashboardScreenState extends State<InvestigatorDashboardScreen> {
  final _inrFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InvestigatorClaimsProvider>().fetchAssignedClaims();
    });
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('MMM dd, yyyy').format(dt);
    } catch (_) {
      return iso.split('T')[0];
    }
  }

  String _toCapitalized(String? text) {
    if (text == null || text.isEmpty) return 'Vehicle';
    return '${text[0].toUpperCase()}${text.substring(1).toLowerCase()}';
  }

  IconData _vehicleIcon(String? type) {
    switch (type?.toUpperCase()) {
      case 'CAR':   return Icons.directions_car_rounded;
      case 'BIKE':  return Icons.two_wheeler_rounded;
      case 'TRUCK': return Icons.local_shipping_rounded;
      case 'AUTO':  return Icons.electric_rickshaw_rounded;
      default:      return Icons.directions_car_outlined;
    }
  }

  Color _getFraudStatusColor(String? status, double score) {
    if (status == null) return AppTheme.getRiskColor(score);
    switch (status.toUpperCase()) {
      case 'CLEAR':
        return AppTheme.successGreen;
      case 'SUSPECTED':
        return AppTheme.warningAmber;
      case 'CONFIRMED':
        return AppTheme.dangerRed;
      default:
        return AppTheme.getRiskColor(score);
    }
  }

  String _getFraudStatusText(String? status, double score) {
    final pct = score.toInt();
    if (status == null) return '$pct% PENDING';
    switch (status.toUpperCase()) {
      case 'CLEAR':
        return '$pct% CLEAR';
      case 'SUSPECTED':
        return '$pct% SUSPECTED';
      case 'CONFIRMED':
        return '$pct% CONFIRMED';
      default:
        return '$pct% PENDING';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = Provider.of<AuthProvider>(context).currentUser;

    // Listen to real-time events & provider state
    context.watch<RealtimeProvider>();
    final provider = context.watch<InvestigatorClaimsProvider>();
    final claims = provider.claims;

    // Calculate metrics dynamically
    final assignedCount = claims.length;
    final pendingCount = claims.where((c) => c.isPendingInvestigation).length;
    final completedCount = claims.where((c) => c.isCompletedInvestigation).length;

    // Display first 3 cases on dashboard (or all if onSeeAll is not provided)
    final displayClaims = widget.onSeeAll != null ? claims.take(3).toList() : claims;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchAssignedClaims(),
        color: AppTheme.primaryBlue,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header Row ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Investigator',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.fullName ?? 'Agent Portal',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        // Bell Notification icon with red badge
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : Colors.grey[200]!,
                                ),
                              ),
                              child: Icon(
                                Icons.notifications_outlined,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.dangerRed,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Metrics Row ──
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'Assigned',
                            '$assignedCount',
                            Icons.work_outline,
                            AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'Pending',
                            '$pendingCount',
                            Icons.search_rounded,
                            AppTheme.warningAmber,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'Completed',
                            '$completedCount',
                            Icons.check_circle_outline,
                            AppTheme.successGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // ── Section Title Row ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Assigned Cases',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.onSeeAll != null)
                          TextButton(
                            onPressed: widget.onSeeAll,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'See all',
                              style: TextStyle(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Assigned Cases List ──
            if (provider.isLoading && displayClaims.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (displayClaims.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(
                    child: Text(
                      'No active claims currently assigned to you.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final claim = displayClaims[index];
                    final statusColor = AppTheme.getStatusColor(claim.status);
                    final fraudColor = _getFraudStatusColor(claim.fraudStatus, claim.fraudScore);
                    final fraudText = _getFraudStatusText(claim.fraudStatus, claim.fraudScore);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : Colors.grey[200]!,
                          ),
                          boxShadow: isDark
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(5),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final res = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => InvestigationDetailScreen(claimId: claim.id),
                                  ),
                                );
                                if (res == true && context.mounted) {
                                  context.read<InvestigatorClaimsProvider>().fetchAssignedClaims();
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left side vehicle icon
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue.withAlpha(15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _vehicleIcon(claim.claimType),
                                        color: AppTheme.primaryBlue,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // Right side info block
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                claim.claimNumber ?? claim.id,
                                                style: TextStyle(
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                _inrFormat.format(claim.claimAmount),
                                                style: TextStyle(
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_toCapitalized(claim.claimType)} · ${claim.policyHolderName ?? 'N/A'} · ${_fmtDate(claim.createdAt)}',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              // Status Pill
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withAlpha(15),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: statusColor.withAlpha(40)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 6,
                                                      height: 6,
                                                      decoration: BoxDecoration(
                                                        color: statusColor,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      claim.status.replaceAll('_', ' '),
                                                      style: TextStyle(
                                                        color: statusColor,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // Fraud status pill
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: fraudColor.withAlpha(15),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: fraudColor.withAlpha(40)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 6,
                                                      height: 6,
                                                      decoration: BoxDecoration(
                                                        color: fraudColor,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      claim.status == 'APPROVED' || claim.status == 'REJECTED'
                                                          ? fraudText
                                                          : fraudText,
                                                      style: TextStyle(
                                                        color: fraudColor,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: displayClaims.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey[200]!,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(5),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

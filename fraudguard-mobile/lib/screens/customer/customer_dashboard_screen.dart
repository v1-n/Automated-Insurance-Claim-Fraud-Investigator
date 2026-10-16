import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/claim_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/claim_service.dart';
import '../../theme/app_theme.dart';
import 'claim_detail_screen.dart';
import 'submit_claim_screen.dart';

class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() => _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  final ClaimService _claimService = ClaimService();
  final _inrFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  List<ClaimModel> _claims = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClaims();
  }

  Future<void> _loadClaims() async {
    setState(() => _isLoading = true);
    try {
      final claims = await _claimService.getMyClaims();
      setState(() {
        _claims = claims;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  // ── vehicle icon per claim type ──────────────────────
  IconData _vehicleIcon(String? type) {
    switch (type?.toUpperCase()) {
      case 'CAR':   return Icons.directions_car_rounded;
      case 'BIKE':  return Icons.two_wheeler_rounded;
      case 'TRUCK': return Icons.local_shipping_rounded;
      case 'AUTO':  return Icons.electric_rickshaw_rounded;
      default:      return Icons.directions_car_outlined;
    }
  }

  // ── formatted date from ISO string ──────────────────
  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('MMM dd, yyyy').format(dt);
    } catch (_) {
      return iso.split('T')[0];
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;

    final total      = _claims.length;
    final underReview= _claims.where((c) => c.status == 'UNDER_REVIEW').length;
    final approved   = _claims.where((c) => c.status == 'APPROVED').length;
    final rejected   = _claims.where((c) => c.status == 'REJECTED').length;
    final pending    = _claims.where((c) => c.status == 'PENDING').length;

    // show only 4 most recent
    final recentClaims = _claims.take(4).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubmitClaimScreen()),
          );
          if (result == true) _loadClaims();
        },
        backgroundColor: AppTheme.primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'File a Claim',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadClaims,
        color: AppTheme.primaryBlue,
        child: CustomScrollView(
          slivers: [

            // ── TOP APP BAR ──────────────────────────────────
            SliverToBoxAdapter(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      // Greeting
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, ${user?.fullName.split(' ').first ?? 'User'}',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Welcome back to FraudGuard',
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Tenant badge
                      if (user?.tenantCode != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withAlpha(40),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.primaryBlue.withAlpha(60)),
                          ),
                          child: Text(
                            user!.tenantCode!,
                            style: const TextStyle(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(width: 10),
                      // Notification bell
                      Stack(
                        children: [
                          Icon(
                            Icons.notifications_outlined,
                            color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                            size: 26,
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
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
                ),
              ),
            ),

            // ── STATS CARDS ROW ─────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _isLoading
                    ? const Center(
                        heightFactor: 3,
                        child: CircularProgressIndicator(),
                      )
                    : Row(
                        children: [
                          _StatCard(
                            icon: Icons.article_outlined,
                            iconColor: AppTheme.primaryBlue,
                            count: total,
                            label: 'Total Claims',
                          ),
                          const SizedBox(width: 10),
                          _StatCard(
                            icon: Icons.search_rounded,
                            iconColor: AppTheme.warningAmber,
                            count: underReview,
                            label: 'Under Review',
                          ),
                          const SizedBox(width: 10),
                          _StatCard(
                            icon: Icons.check_circle_outline_rounded,
                            iconColor: AppTheme.successGreen,
                            count: approved,
                            label: 'Approved',
                          ),
                        ],
                      ),
              ),
            ),

            // ── SECOND ROW: PENDING + REJECTED ──────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: _isLoading
                    ? const SizedBox.shrink()
                    : Row(
                        children: [
                          _StatCard(
                            icon: Icons.hourglass_empty_rounded,
                            iconColor: Colors.blueAccent,
                            count: pending,
                            label: 'Pending',
                            wide: true,
                          ),
                          const SizedBox(width: 10),
                          _StatCard(
                            icon: Icons.cancel_outlined,
                            iconColor: AppTheme.dangerRed,
                            count: rejected,
                            label: 'Rejected',
                            wide: true,
                          ),
                        ],
                      ),
              ),
            ),

            // (Removed "Insure Your Vehicle" banner — users buy from Policies tab)

            // ── RECENT CLAIMS HEADER ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Claims',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        // Navigate to My Claims tab (index 1 in bottom nav)
                        DefaultTabController.of(context).animateTo(1);
                      },
                      child: const Text(
                        'See all',
                        style: TextStyle(color: AppTheme.primaryBlue, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── CLAIM CARDS / EMPTY STATE ────────────────────
            if (!_isLoading && _claims.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
                  child: Column(
                    children: [
                      Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey[700]),
                      const SizedBox(height: 16),
                      Text(
                        'No claims yet',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap "File a Claim" to submit your first claim',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.grey[500] : const Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= recentClaims.length) return null;
                    return _ClaimCard(
                      claim: recentClaims[index],
                      vehicleIcon: _vehicleIcon(recentClaims[index].claimType),
                      formatDate: _fmtDate,
                      formatCurrency: _inrFormat.format,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ClaimDetailScreen(claimId: recentClaims[index].id),
                          ),
                        );
                        _loadClaims();
                      },
                    );
                  },
                  childCount: recentClaims.length,
                ),
              ),

            // Bottom padding for FAB
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Stat Card Widget
// ─────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final int count;
  final String label;
  final bool wide;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.count,
    required this.label,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      flex: wide ? 1 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 10,
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
                color: iconColor.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              '$count',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Claim List Card Widget
// ─────────────────────────────────────────────────────────
class _ClaimCard extends StatelessWidget {
  final ClaimModel claim;
  final IconData vehicleIcon;
  final String Function(String?) formatDate;
  final String Function(num) formatCurrency;
  final VoidCallback onTap;

  const _ClaimCard({
    required this.claim,
    required this.vehicleIcon,
    required this.formatDate,
    required this.formatCurrency,
    required this.onTap,
  });

  Color _statusColor(String status) => AppTheme.getStatusColor(status);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _statusColor(claim.status);
    final displayType = claim.claimType?.toCapitalized() ?? 'Vehicle';
    final dateStr = formatDate(claim.createdAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Vehicle icon circle
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(vehicleIcon, color: AppTheme.primaryBlue, size: 22),
            ),
            const SizedBox(width: 14),

            // Claim info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    claim.claimNumber ?? claim.id,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$displayType  ·  $dateStr',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Status pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          claim.status.replaceAll('_', ' '),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Amount
            Text(
              formatCurrency(claim.claimAmount),
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on String {
  String toCapitalized() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}

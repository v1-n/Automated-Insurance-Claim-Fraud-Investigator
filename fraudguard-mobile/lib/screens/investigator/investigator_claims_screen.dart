import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/investigator_claims_provider.dart';
import '../../providers/realtime_provider.dart';
import '../../theme/app_theme.dart';
import 'investigation_detail_screen.dart';

class InvestigatorClaimsScreen extends StatefulWidget {
  const InvestigatorClaimsScreen({super.key});

  @override
  State<InvestigatorClaimsScreen> createState() => _InvestigatorClaimsScreenState();
}

class _InvestigatorClaimsScreenState extends State<InvestigatorClaimsScreen> {
  final _inrFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'ALL'; // ALL, UNDER_REVIEW, COMPLETED

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InvestigatorClaimsProvider>().fetchAssignedClaims();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'N/A';
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
      case 'AUTO':
      case 'FOUR_WHEELER':
      case 'CAR':
        return Icons.directions_car_outlined;
      case 'TWO_WHEELER':
      case 'BIKE':
        return Icons.two_wheeler_outlined;
      case 'COMMERCIAL':
      case 'TRUCK':
        return Icons.local_shipping_outlined;
      default:
        return Icons.security_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    context.watch<RealtimeProvider>();

    final backgroundColor = isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Assigned Case Files',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Consumer<InvestigatorClaimsProvider>(
        builder: (context, provider, child) {
          final claims = provider.claims;

          final filteredClaims = claims.where((c) {
            final matchesSearch = _searchQuery.isEmpty ||
                (c.claimNumber?.toLowerCase().contains(_searchQuery.toLowerCase()) == true) ||
                c.policyNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (c.policyHolderName?.toLowerCase().contains(_searchQuery.toLowerCase()) == true) ||
                (c.incidentCity?.toLowerCase().contains(_searchQuery.toLowerCase()) == true);

            if (!matchesSearch) return false;

            if (_selectedFilter == 'UNDER_REVIEW') {
              return c.isPendingInvestigation;
            } else if (_selectedFilter == 'COMPLETED') {
              return c.isCompletedInvestigation;
            }
            return true;
          }).toList();

          return Column(
            children: [
              // Search & Filter Header
              Container(
                color: cardColor,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    // Search Input
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search by case ID, claimant, policy...',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.primaryBlue),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Filter Chips Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('ALL', 'All Cases (${claims.length})', isDark),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'UNDER_REVIEW',
                            'Pending Review (${claims.where((c) => c.isPendingInvestigation).length})',
                            isDark,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'COMPLETED',
                            'Reviewed (${claims.where((c) => c.isCompletedInvestigation).length})',
                            isDark,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Cases List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.fetchAssignedClaims(),
                  color: AppTheme.primaryBlue,
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredClaims.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryBlue.withAlpha(15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.folder_off_outlined, size: 48, color: AppTheme.primaryBlue),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No assigned cases found',
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? 'Try clearing your search query.'
                                            : 'No investigation files in this filter.',
                                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredClaims.length,
                              itemBuilder: (context, idx) {
                                final claim = filteredClaims[idx];
                                final statusColor = AppTheme.getStatusColor(claim.status);
                                final fraudColor = AppTheme.getRiskColor(claim.fraudScore);
                                final fraudText = claim.fraudStatus != null && claim.fraudStatus != 'PENDING_ANALYSIS'
                                    ? '${claim.fraudScore.toInt()}% ${claim.fraudStatus}'
                                    : '${claim.fraudScore.toInt()}% RISK';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: borderColor),
                                    boxShadow: isDark
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withAlpha(6),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            )
                                          ],
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () async {
                                      final res = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => InvestigationDetailScreen(claimId: claim.id),
                                        ),
                                      );
                                      if (res == true && context.mounted) {
                                        provider.fetchAssignedClaims();
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Top Row: Vehicle Icon + Claim Number & Amount
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryBlue.withAlpha(15),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Icon(
                                                  _vehicleIcon(claim.claimType),
                                                  color: AppTheme.primaryBlue,
                                                  size: 22,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '#${claim.claimNumber ?? claim.id}',
                                                      style: TextStyle(
                                                        color: textColor,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${_toCapitalized(claim.claimType)} • Policy: ${claim.policyNumber}',
                                                      style: TextStyle(
                                                        color: Colors.grey[500],
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                _inrFormat.format(claim.claimAmount),
                                                style: const TextStyle(
                                                  color: AppTheme.primaryBlue,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),

                                          // Middle Info Row: Claimant Name & Incident Date
                                          Row(
                                            children: [
                                              Icon(Icons.person_outline, size: 14, color: Colors.grey[400]),
                                              const SizedBox(width: 4),
                                              Text(
                                                claim.policyHolderName ?? 'N/A',
                                                style: TextStyle(
                                                  color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              if (claim.incidentCity != null && claim.incidentCity!.isNotEmpty) ...[
                                                Text(' • ', style: TextStyle(color: Colors.grey[400])),
                                                Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[400]),
                                                const SizedBox(width: 2),
                                                Text(
                                                  claim.incidentCity!,
                                                  style: TextStyle(
                                                    color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                              const Spacer(),
                                              Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey[400]),
                                              const SizedBox(width: 4),
                                              Text(
                                                _fmtDate(claim.incidentDate),
                                                style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),

                                          // Bottom Row: Status Badges
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
                                                      fraudText,
                                                      style: TextStyle(
                                                        color: fraudColor,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const Spacer(),
                                              Icon(
                                                Icons.chevron_right,
                                                color: Colors.grey[400],
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, bool isDark) {
    final isSelected = _selectedFilter == key;
    final activeColor = AppTheme.primaryBlue;
    final inactiveBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final inactiveText = isDark ? Colors.grey[400]! : const Color(0xFF64748B);

    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : inactiveBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : inactiveText,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

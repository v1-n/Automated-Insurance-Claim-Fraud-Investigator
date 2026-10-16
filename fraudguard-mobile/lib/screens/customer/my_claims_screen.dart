import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/customer_claims_provider.dart';
import '../../providers/realtime_provider.dart';
import '../../theme/app_theme.dart';
import 'claim_detail_screen.dart';

class MyClaimsScreen extends StatefulWidget {
  const MyClaimsScreen({super.key});

  @override
  State<MyClaimsScreen> createState() => _MyClaimsScreenState();
}

class _MyClaimsScreenState extends State<MyClaimsScreen> {
  final _inrFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  String _selectedFilter = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerClaimsProvider>().fetchMyClaims();
    });
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    context.watch<RealtimeProvider>();

    return Consumer<CustomerClaimsProvider>(
      builder: (context, provider, child) {
        final claims = provider.claims;
        final filteredClaims = claims.where((c) {
          final matchesFilter = _selectedFilter == 'ALL' || c.status == _selectedFilter;
          final matchesSearch = _searchQuery.isEmpty ||
              c.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              c.policyNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (c.claimType?.toLowerCase().contains(_searchQuery.toLowerCase()) == true);
          return matchesFilter && matchesSearch;
        }).toList();

        return Scaffold(
          backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
            elevation: 0,
            title: Text(
              'My Claims',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: Column(
            children: [
              // ── Search Bar ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
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
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Search by claim ID or type...',
                      hintStyle: TextStyle(color: isDark ? Colors.grey[500] : const Color(0xFF64748B), fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),

              // ── Horizontal Filter Chips ─────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'All Claims'),
                      _buildFilterChip('PENDING', 'Pending'),
                      _buildFilterChip('UNDER_REVIEW', 'In Review'),
                      _buildFilterChip('APPROVED', 'Approved'),
                      _buildFilterChip('REJECTED', 'Rejected'),
                    ],
                  ),
                ),
              ),

              // ── List Area ───────────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.fetchMyClaims(),
                  color: AppTheme.primaryBlue,
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredClaims.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 100),
                                Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.folder_off_outlined, size: 54, color: Colors.grey[700]),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No claims found',
                                        style: TextStyle(color: Colors.grey[400], fontSize: 16, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: filteredClaims.length,
                              itemBuilder: (context, index) {
                                final claim = filteredClaims[index];
                                final color = AppTheme.getStatusColor(claim.status);
                                final displayType = claim.claimType?.toCapitalized() ?? 'Vehicle';
                                final dateStr = _fmtDate(claim.createdAt);

                                return GestureDetector(
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ClaimDetailScreen(claimId: claim.id),
                                      ),
                                    );
                                    if (context.mounted) {
                                      provider.fetchMyClaims();
                                    }
                                  },
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
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
                                          child: Icon(_vehicleIcon(claim.claimType), color: AppTheme.primaryBlue, size: 22),
                                        ),
                                        const SizedBox(width: 14),

                                        // Claim info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                claim.claimNumber ?? claim.id, // Only show claimNumber from backend
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
                                          _inrFormat.format(claim.claimAmount),
                                          style: TextStyle(
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
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
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedFilter == filterKey;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        selected: isSelected,
        label: Text(label),
        labelStyle: TextStyle(
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        selectedColor: AppTheme.primaryBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected
                ? AppTheme.primaryBlue
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: 1,
          ),
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedFilter = filterKey;
            });
          }
        },
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

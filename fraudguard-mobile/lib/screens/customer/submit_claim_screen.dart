import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/claim_service.dart';
import '../../services/document_service.dart';
import '../../services/policy_service.dart';
import '../../theme/app_theme.dart';
import 'buy_policy_screen.dart';
import 'document_upload_sheet.dart';

class SubmitClaimScreen extends StatefulWidget {
  const SubmitClaimScreen({super.key});

  @override
  State<SubmitClaimScreen> createState() => _SubmitClaimScreenState();
}

class _SubmitClaimScreenState extends State<SubmitClaimScreen> {
  final _formKey = GlobalKey<FormState>();
  final _claimService = ClaimService();
  final _documentService = DocumentService();
  final _policyService = PolicyService();

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  String _selectedClaimType = 'CAR';
  DateTime? _selectedDateTime;
  final List<PickedDocument> _attachedDocuments = [];
  bool _isSubmitting = false;
  bool _hasActivePolicy = true; // assume true until check completes
  bool _isCheckingPolicy = true;

  @override
  void initState() {
    super.initState();
    _checkUserPolicies();
  }

  Future<void> _checkUserPolicies() async {
    try {
      final policies = await _policyService.getMyPolicies();
      if (mounted) {
        setState(() {
          _hasActivePolicy = policies.any((p) => p.policyStatus == 'ACTIVE');
          _isCheckingPolicy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasActivePolicy = false;
          _isCheckingPolicy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppTheme.primaryBlue,
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E293B),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: AppTheme.primaryBlue,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF0F172A),
                  ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: AppTheme.primaryBlue,
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E293B),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: AppTheme.primaryBlue,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Color(0xFF0F172A),
                  ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _openUploadSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DocumentUploadSheet(
        onFilesPicked: (files) {
          setState(() {
            _attachedDocuments.addAll(files);
          });
        },
      ),
    );
  }

  void _showSnackBar(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showNoPolicyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warningAmber, size: 28),
            SizedBox(width: 10),
            Text('No Active Insurance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'You do not have any active insurance policy. You must buy or activate an insurance policy first before submitting a claim.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BuyPolicyScreen()),
              ).then((_) => _checkUserPolicies());
            },
            child: const Text('Buy Policy First', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_hasActivePolicy) {
      _showNoPolicyDialog();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedDateTime == null) {
      _showSnackBar('Please select the incident date & time', AppTheme.dangerRed);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final isoDate = _selectedDateTime!.toUtc().toIso8601String();
      final newClaim = await _claimService.submitClaim(
        claimAmount: double.parse(_amountController.text.trim()),
        incidentDate: isoDate,
        description: _descriptionController.text.trim(),
        claimType: _selectedClaimType,
        incidentAddress: _addressController.text.trim(),
        incidentCity: _cityController.text.trim(),
        incidentState: _stateController.text.trim(),
      );

      // Upload all attached evidence documents
      for (var doc in _attachedDocuments) {
        await _documentService.uploadDocument(
          claimId: newClaim.id,
          filePath: doc.filePath,
          documentType: doc.documentType,
        );
      }

      _showSnackBar('Claim submitted successfully!', AppTheme.successGreen);

      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      } else {
        // Reset form if in main navigation tab shell
        _formKey.currentState!.reset();
        setState(() {
          _amountController.clear();
          _descriptionController.clear();
          _addressController.clear();
          _cityController.clear();
          _stateController.clear();
          _selectedDateTime = null;
          _attachedDocuments.clear();
          _selectedClaimType = 'CAR';
        });
      }
    } catch (e) {
      _showSnackBar('Failed to submit claim: $e', AppTheme.dangerRed);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _inputDecoration(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: isDark ? Colors.grey[400] : const Color(0xFF64748B), fontSize: 14),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.white.withAlpha(15) : const Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.white.withAlpha(15) : const Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.dangerRed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showBackButton = Navigator.canPop(context);
    final formattedDateTime = _selectedDateTime != null
        ? DateFormat('MM/dd/yyyy, hh:mm a').format(_selectedDateTime!)
        : 'mm/dd/yyyy, --:-- --';

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
        elevation: 0,
        leading: showBackButton
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          'File Claim',
          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── NO POLICY WARNING BANNER ────────────────────────
                if (!_isCheckingPolicy && !_hasActivePolicy) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.warningAmber.withAlpha(25),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.warningAmber.withAlpha(120)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: AppTheme.warningAmber, size: 24),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No Active Insurance Policy',
                                style: TextStyle(
                                  color: AppTheme.warningAmber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'You do not have any active insurance policy. You must buy or activate an insurance policy first before submitting a claim.',
                          style: TextStyle(fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.warningAmber,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const BuyPolicyScreen()),
                              ).then((_) => _checkUserPolicies());
                            },
                            icon: const Icon(Icons.shield_outlined, size: 18),
                            label: const Text(
                              'Buy Policy First',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── SECTION 1: CLAIM INFORMATION ──────────────────────
                Text(
                  'Claim Information',
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // Claim Type
                DropdownButtonFormField<String>(
                  initialValue: _selectedClaimType,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 15),
                  decoration: _inputDecoration('Claim Type *', isDark),
                  items: const [
                    DropdownMenuItem(value: 'CAR', child: Text('Car')),
                    DropdownMenuItem(value: 'BIKE', child: Text('Bike')),
                    DropdownMenuItem(value: 'TRUCK', child: Text('Truck')),
                    DropdownMenuItem(value: 'AUTO', child: Text('Auto')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedClaimType = val);
                  },
                ),
                const SizedBox(height: 16),

                // Claim Amount
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: _inputDecoration('Claim Amount (₹) *', isDark),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter the amount';
                    final parsed = double.tryParse(val.trim());
                    if (parsed == null || parsed <= 0) return 'Please enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: _inputDecoration('Description *', isDark),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter description';
                    if (val.trim().length < 10) return 'Must be at least 10 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ── SECTION 2: INCIDENT DETAILS ────────────────────────
                Text(
                  'Incident Details',
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // Incident Date & Time Card Selector
                GestureDetector(
                  onTap: _pickDateTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white.withAlpha(15) : const Color(0xFFE2E8F0)),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Incident Date & Time *',
                                style: TextStyle(color: isDark ? Colors.grey[400] : const Color(0xFF64748B), fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formattedDateTime,
                                style: TextStyle(
                                  color: _selectedDateTime != null
                                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                      : (isDark ? Colors.grey[500] : const Color(0xFF94A3B8)),
                                  fontSize: 15,
                                  fontWeight: _selectedDateTime != null ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.calendar_today_outlined, color: isDark ? Colors.grey[400] : const Color(0xFF64748B), size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Incident Address
                TextFormField(
                  controller: _addressController,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: _inputDecoration('Incident Address *', isDark),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Address is required' : null,
                ),
                const SizedBox(height: 16),

                // City
                TextFormField(
                  controller: _cityController,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: _inputDecoration('City *', isDark),
                  validator: (val) => val == null || val.trim().isEmpty ? 'City is required' : null,
                ),
                const SizedBox(height: 16),

                // State
                TextFormField(
                  controller: _stateController,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: _inputDecoration('State *', isDark),
                  validator: (val) => val == null || val.trim().isEmpty ? 'State is required' : null,
                ),
                const SizedBox(height: 24),

                // ── SECTION 3: EVIDENCE & DOCUMENTS ───────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Evidence & Documents',
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: _openUploadSheet,
                      icon: const Icon(Icons.add_rounded, color: AppTheme.primaryBlue),
                      label: const Text('Add', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_attachedDocuments.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white.withAlpha(10) : const Color(0xFFE2E8F0)),
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
                    child: Center(
                      child: Text(
                        'No files attached. Tap "Add" to upload photos/documents.',
                        style: TextStyle(color: isDark ? Colors.grey[500] : const Color(0xFF64748B), fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _attachedDocuments.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final doc = _attachedDocuments[idx];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primaryBlue.withAlpha(40)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.insert_drive_file_outlined, color: AppTheme.primaryBlue, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc.fileName,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    doc.documentType,
                                    style: TextStyle(color: isDark ? Colors.grey[400] : const Color(0xFF64748B), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: AppTheme.dangerRed, size: 18),
                              onPressed: () {
                                setState(() {
                                  _attachedDocuments.removeAt(idx);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 32),

                // Submit Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'SUBMIT CLAIM',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                        ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

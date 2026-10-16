import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../models/claim_model.dart';
import '../../models/document_model.dart';
import '../../services/claim_service.dart';
import '../../services/document_service.dart';
import '../../theme/app_theme.dart';
import 'document_upload_sheet.dart';

class ClaimDetailScreen extends StatefulWidget {
  final String claimId;
  const ClaimDetailScreen({super.key, required this.claimId});

  @override
  State<ClaimDetailScreen> createState() => _ClaimDetailScreenState();
}

class _ClaimDetailScreenState extends State<ClaimDetailScreen> {
  final ClaimService _claimService = ClaimService();
  final DocumentService _documentService = DocumentService();
  final _inrFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  ClaimModel? _claim;
  List<DocumentModel> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      final claim = await _claimService.getClaimById(widget.claimId);
      final docs  = await _documentService.getClaimDocuments(widget.claimId);
      setState(() {
        _claim     = claim;
        _documents = docs;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadDocument(DocumentModel doc) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading ${doc.fileName}...'),
          backgroundColor: AppTheme.primaryBlue,
          duration: const Duration(seconds: 1),
        ),
      );

      List<int> bytes;
      if (doc.fileUrl != null && doc.fileUrl!.startsWith('http')) {
        final response = await http.get(Uri.parse(doc.fileUrl!));
        if (response.statusCode == 200) {
          bytes = response.bodyBytes;
        } else {
          bytes = await _documentService.downloadDocument(doc.id);
        }
      } else {
        bytes = await _documentService.downloadDocument(doc.id);
      }

      final Uint8List uint8list = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

      final String? selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Document',
        fileName: doc.fileName,
        bytes: uint8list,
      );

      if (selectedPath != null) {
        // On desktop platforms, we need to write the bytes manually.
        // On Android/iOS, FilePicker.saveFile already writes the bytes when passed via parameters.
        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          final file = File(selectedPath);
          await file.writeAsBytes(uint8list);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Document saved successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download document: $e'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  Future<void> _uploadNewDocument() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DocumentUploadSheet(
        claimId: widget.claimId,
        onUploadSuccess: _fetchDetails,
      ),
    );
  }

  String _fmtDate(String? iso) {
    if (iso == null) return 'N/A';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('MMM dd, yyyy').format(dt);
    } catch (_) {
      return iso.split('T')[0];
    }
  }

  String _fmtFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes >= 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
          title: Text(
            'Claim Details',
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          iconTheme: IconThemeData(color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_claim == null) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
          title: Text(
            'Claim Details',
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          iconTheme: IconThemeData(color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
        body: Center(
          child: Text(
            'Claim not found.',
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
      );
    }

    final c = _claim!;
    final statusColor = AppTheme.getStatusColor(c.status);
    final isRejected  = c.status == 'REJECTED';

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.claimNumber ?? c.id,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              '${c.claimType?.toCapitalized() ?? 'Vehicle'} claim',
              style: TextStyle(color: isDark ? Colors.grey[400] : const Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDetails,
        color: AppTheme.primaryBlue,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── AMOUNT + STATUS CARD ────────────────────
              Container(
                padding: const EdgeInsets.all(20),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Claim Amount',
                          style: TextStyle(color: isDark ? Colors.grey[400] : const Color(0xFF64748B), fontSize: 13),
                        ),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor.withAlpha(80)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                c.status.replaceAll('_', ' '),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _inrFormat.format(c.claimAmount),
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submitted ${_fmtDate(c.createdAt)}',
                      style: TextStyle(color: isDark ? Colors.grey[500] : const Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── CLAIM STATUS TRACKER STEPPER ───────────
              ClaimStepper(claim: c),

              const SizedBox(height: 16),

              // ── REJECTION REASON (only when REJECTED) ──
              if (isRejected) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerRed.withAlpha(20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.dangerRed.withAlpha(60)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reason for rejection:',
                        style: TextStyle(
                          color: AppTheme.dangerRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          '────────────────────────────',
                          style: TextStyle(color: AppTheme.dangerRed, fontSize: 10),
                        ),
                      ),
                      Text(
                        (c.decisionNotes != null && c.decisionNotes!.isNotEmpty)
                            ? c.decisionNotes!
                            : 'No rejection reason provided.',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── APPROVAL DECISION NOTE (only when APPROVED) ──
              if (c.status == 'APPROVED') ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withAlpha(20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.successGreen.withAlpha(60)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Decision:',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (c.decisionNotes != null && c.decisionNotes!.isNotEmpty)
                            ? c.decisionNotes!
                            : 'Your claim has been approved after reviewing the submitted documents.',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── INCIDENT DETAILS CARD ───────────────────
              Text(
                'Incident Details',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Incident Date
                    _IncidentDetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Incident Date',
                      value: _fmtDate(c.incidentDate),
                    ),
                    Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), height: 20),

                    // Location
                    _IncidentDetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      value: c.incidentLocation,
                    ),

                    // Description
                    if (c.description != null && c.description!.isNotEmpty) ...[
                      Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), height: 20),
                      Text(
                        'Description',
                        style: TextStyle(color: isDark ? Colors.grey[400] : const Color(0xFF64748B), fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.description!,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── ATTACHMENTS ─────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attachments (${_documents.length})',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_rounded, color: AppTheme.primaryBlue),
                    onPressed: _uploadNewDocument,
                    tooltip: 'Upload Document',
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_documents.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
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
                  child: Center(
                    child: Text(
                      'No documents attached yet.',
                      style: TextStyle(color: isDark ? Colors.grey[500] : const Color(0xFF64748B)),
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 5,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: _documents.length,
                  itemBuilder: (_, idx) {
                    final doc = _documents[idx];
                    return _DocumentTile(
                      doc: doc,
                      formattedSize: _fmtFileSize(doc.fileSize),
                      onTap: () => _downloadDocument(doc),
                    );
                  },
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadNewDocument,
        backgroundColor: AppTheme.primaryBlue,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Incident Detail Row
// ─────────────────────────────────────────────────────────
class _IncidentDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _IncidentDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: isDark ? Colors.grey[500] : const Color(0xFF64748B), size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: isDark ? Colors.grey[400] : const Color(0xFF64748B), fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Document Grid Tile
// ─────────────────────────────────────────────────────────
class _DocumentTile extends StatelessWidget {
  final DocumentModel doc;
  final String formattedSize;
  final VoidCallback onTap;

  const _DocumentTile({
    required this.doc,
    required this.formattedSize,
    required this.onTap,
  });

  String _cleanType(String t) {
    return t.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.insert_drive_file_outlined, size: 36, color: Color(0xFF4B6CB7)),
            const SizedBox(height: 8),
            Text(
              _cleanType(doc.documentType),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (formattedSize.isNotEmpty)
              Text(
                formattedSize,
                style: TextStyle(color: isDark ? Colors.grey[500] : const Color(0xFF64748B), fontSize: 11),
              ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.download_outlined, color: AppTheme.primaryBlue, size: 18),
              ],
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

enum StepState {
  completed,
  active,
  failed,
  pending,
}

class ClaimStepper extends StatelessWidget {
  final ClaimModel claim;

  const ClaimStepper({super.key, required this.claim});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final bool isApproved = claim.status == 'APPROVED';
    final bool isRejected = claim.status == 'REJECTED';
    final bool isDecided = isApproved || isRejected;

    // Step 1: Claim Submitted (always complete)
    const step1State = StepState.completed;
    const step1Title = 'Claim Submitted';
    const step1Subtitle = 'Your claim has been successfully submitted.';

    // Step 2: Investigation
    final bool isInvestigationCompleted = (claim.fraudStatus != null && claim.fraudStatus != 'PENDING_ANALYSIS') || isDecided;
    final StepState step2State = isInvestigationCompleted ? StepState.completed : StepState.active;
    final String step2Title = isInvestigationCompleted ? 'Investigation Completed' : 'Under Investigation';
    final String step2Subtitle = isInvestigationCompleted
        ? 'Your claim has completed the investigation stage.'
        : 'Our investigation team is reviewing your claim.';

    // Step 3: Final Review
    final bool isFinalReviewCompleted = isDecided;
    final bool isFinalReviewActive = !isDecided && isInvestigationCompleted;
    final StepState step3State = isFinalReviewCompleted
        ? StepState.completed
        : (isFinalReviewActive ? StepState.active : StepState.pending);
    const String step3Title = 'Final Review';
    final String step3Subtitle = isFinalReviewCompleted
        ? 'Final review completed.'
        : (isFinalReviewActive ? 'Your claim is awaiting final approval.' : 'Awaiting final review.');

    // Step 4: Decision
    final StepState step4State = isDecided
        ? (isApproved ? StepState.completed : StepState.failed)
        : StepState.pending;
    final String step4Title = isDecided
        ? (isApproved ? 'Approved' : 'Rejected')
        : 'Decision';
    final String step4Subtitle = isDecided
        ? (isApproved ? '🎉 Your claim has been approved.' : 'Rejected')
        : 'Decision pending.';

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : Colors.grey[200]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Claim Status Tracker',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 20),
            _buildStepRow(context, step1State, step1Title, step1Subtitle, isLast: false),
            _buildStepRow(context, step2State, step2Title, step2Subtitle, isLast: false),
            _buildStepRow(context, step3State, step3Title, step3Subtitle, isLast: false),
            _buildStepRow(context, step4State, step4Title, step4Subtitle, isLast: true),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow(
    BuildContext context,
    StepState state,
    String title,
    String subtitle, {
    required bool isLast,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color iconColor;
    Widget iconWidget;

    switch (state) {
      case StepState.completed:
        iconColor = AppTheme.successGreen;
        iconWidget = const Icon(Icons.check, color: Colors.white, size: 14);
        break;
      case StepState.active:
        iconColor = AppTheme.primaryBlue;
        iconWidget = Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        );
        break;
      case StepState.failed:
        iconColor = AppTheme.dangerRed;
        iconWidget = const Icon(Icons.close, color: Colors.white, size: 14);
        break;
      case StepState.pending:
        iconColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
        iconWidget = const SizedBox.shrink();
        break;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: state == StepState.pending ? Colors.transparent : iconColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: state == StepState.pending ? iconColor : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Center(child: iconWidget),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: state == StepState.completed
                        ? AppTheme.successGreen
                        : (state == StepState.failed
                            ? AppTheme.dangerRed
                            : (isDark ? const Color(0xFF334155) : Colors.grey[300]!)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: state == StepState.pending
                        ? (isDark ? Colors.grey[500] : Colors.grey[400])
                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

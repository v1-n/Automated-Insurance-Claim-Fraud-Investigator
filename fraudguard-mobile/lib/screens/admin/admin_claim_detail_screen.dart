import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../../models/document_model.dart';
import '../../providers/admin_claim_detail_provider.dart';
import '../../services/document_service.dart';
import '../../theme/app_theme.dart';

class AdminClaimDetailScreen extends StatelessWidget {
  final String claimId;
  const AdminClaimDetailScreen({super.key, required this.claimId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminClaimDetailProvider()..load(claimId),
      child: _AdminClaimDetailBody(claimId: claimId),
    );
  }
}

class _AdminClaimDetailBody extends StatefulWidget {
  final String claimId;
  const _AdminClaimDetailBody({required this.claimId});

  @override
  State<_AdminClaimDetailBody> createState() => _AdminClaimDetailBodyState();
}

class _AdminClaimDetailBodyState extends State<_AdminClaimDetailBody> {
  final _inrFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final _decisionNotesController = TextEditingController();
  final DocumentService _documentService = DocumentService();

  @override
  void dispose() {
    _decisionNotesController.dispose();
    super.dispose();
  }

  String _fmtDate(String? iso) {
    if (iso == null) return 'N/A';
    try {
      return DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso.split('T')[0];
    }
  }

  String _fmtSize(int? b) {
    if (b == null) return '';
    if (b >= 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
    if (b >= 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    return '$b B';
  }

  String _cleanType(String t) => t
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');

  Future<void> _viewDocument(DocumentModel doc) async {
    final messenger = ScaffoldMessenger.of(context);
    if (doc.id.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Document ID is missing. Cannot retrieve document from server.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Opening ${doc.fileName}...',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryBlue,
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      List<int> bytes;
      try {
        bytes = await _documentService.downloadAdminDocument(doc.id);
      } catch (_) {
        if (doc.fileUrl != null && doc.fileUrl!.startsWith('http')) {
          final response = await http.get(Uri.parse(doc.fileUrl!));
          bytes = response.bodyBytes;
        } else {
          rethrow;
        }
      }

      final Uint8List uint8list = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      if (!mounted) return;
      messenger.hideCurrentSnackBar();

      final fileNameLower = doc.fileName.toLowerCase();
      final isImage = fileNameLower.endsWith('.png') ||
          fileNameLower.endsWith('.jpg') ||
          fileNameLower.endsWith('.jpeg') ||
          fileNameLower.endsWith('.webp') ||
          fileNameLower.endsWith('.gif');

      final isText = fileNameLower.endsWith('.txt') ||
          fileNameLower.endsWith('.json') ||
          fileNameLower.endsWith('.csv') ||
          fileNameLower.endsWith('.xml') ||
          fileNameLower.endsWith('.log');

      if (isImage) {
        showDialog(
          context: context,
          builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 600, maxWidth: 800),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              doc.fileName,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.download_rounded, color: AppTheme.primaryBlue),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _downloadDocument(doc);
                            },
                            tooltip: 'Download',
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black54),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: InteractiveViewer(
                            child: Image.memory(
                              uint8list,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Center(
                                child: Text('Unable to display image preview.'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } else if (isText) {
        String content = '';
        try {
          content = String.fromCharCodes(uint8list);
        } catch (_) {
          content = 'Unable to parse text contents.';
        }

        showDialog(
          context: context,
          builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 600, maxWidth: 800),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              doc.fileName,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.download_rounded, color: AppTheme.primaryBlue),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _downloadDocument(doc);
                            },
                            tooltip: 'Download',
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.black54),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            content,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/${doc.fileName}');
        await tempFile.writeAsBytes(uint8list);

        final fileUri = Uri.file(tempFile.path);
        bool launched = false;
        try {
          launched = await launchUrl(fileUri, mode: LaunchMode.externalApplication);
        } catch (_) {
          try {
            launched = await launchUrl(fileUri);
          } catch (_) {}
        }

        if (!mounted) return;

        showDialog(
          context: context,
          builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded, size: 48, color: AppTheme.primaryBlue),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      doc.fileName,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${doc.documentType.replaceAll('_', ' ')} • ${(uint8list.length / 1024).toStringAsFixed(1)} KB',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    if (launched)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, color: AppTheme.successGreen, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Document opened in external viewer',
                              style: TextStyle(color: AppTheme.successGreen, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                await launchUrl(fileUri, mode: LaunchMode.externalApplication);
                              } catch (_) {
                                await launchUrl(fileUri);
                              }
                            },
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text('Open File'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _downloadDocument(doc);
                            },
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Save File'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Close', style: TextStyle(color: Colors.grey[500])),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to view document: $e'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
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
      try {
        bytes = await _documentService.downloadAdminDocument(doc.id);
      } catch (_) {
        if (doc.fileUrl != null && doc.fileUrl!.startsWith('http')) {
          final response = await http.get(Uri.parse(doc.fileUrl!));
          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            bytes = response.bodyBytes;
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      final Uint8List uint8list = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

      final String? selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Document',
        fileName: doc.fileName,
        bytes: uint8list,
      );

      if (selectedPath != null) {
        if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          final file = File(selectedPath);
          await file.writeAsBytes(uint8list);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document saved successfully!'),
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

  void _showAssignSheet(BuildContext context) {
    final provider = context.read<AdminClaimDetailProvider>();
    final investigators = provider.investigators;
    String? selectedId = investigators.isNotEmpty ? investigators.first.investigatorId : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Container(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Assign Investigator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                Text('Select an investigator to review this claim.', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                const SizedBox(height: 20),
                if (investigators.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('No active investigators available.'))
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedId,
                    decoration: InputDecoration(
                      labelText: 'Investigator',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: investigators.map((inv) => DropdownMenuItem(
                      value: inv.investigatorId,
                      child: Text('${inv.investigatorName} (${inv.activeAssignedClaims} active)', style: const TextStyle(fontSize: 14)),
                    )).toList(),
                    onChanged: (val) => setSheet(() => selectedId = val),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: selectedId == null ? null : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      final ok = await provider.assignInvestigator(widget.claimId, selectedId!);
                      messenger.showSnackBar(SnackBar(
                        content: Text(ok ? 'Investigator assigned!' : 'Failed: ${provider.errorMessage}'),
                        backgroundColor: ok ? AppTheme.successGreen : AppTheme.dangerRed,
                      ));
                    },
                    child: const Text('Confirm Assignment'),
                  ),
                ],
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _handleDecision(BuildContext context, bool isApprove) async {
    final provider = context.read<AdminClaimDetailProvider>();
    if (!provider.canMakeDecision) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot finalize decision: Waiting for investigator review.'),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
      return;
    }

    if (_decisionNotesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isApprove
              ? 'Please provide decision notes before approving.'
              : 'Rejection requires mandatory decision notes / reason.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final notes = _decisionNotesController.text.trim();
    final ok = isApprove
        ? await provider.approveClaim(widget.claimId, notes)
        : await provider.rejectClaim(widget.claimId, notes);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? (isApprove ? 'Claim APPROVED!' : 'Claim REJECTED.')
          : 'Failed: ${provider.errorMessage}'),
      backgroundColor: ok ? (isApprove ? AppTheme.successGreen : AppTheme.dangerRed) : AppTheme.dangerRed,
    ));
    if (ok) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey[200]!;
    final labelColor = isDark ? Colors.grey[400]! : const Color(0xFF64748B);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Consumer<AdminClaimDetailProvider>(
      builder: (context, provider, _) {
        // ── Loading ──
        if (provider.status == AdminClaimDetailStatus.loading) {
          return Scaffold(
            appBar: AppBar(title: const Text('Claim Details')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        // ── Error / not found ──
        if (provider.status == AdminClaimDetailStatus.error || provider.claim == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Claim Details')),
            body: Center(child: Text(provider.errorMessage ?? 'Claim not found.')),
          );
        }

        final c = provider.claim!;
        final statusColor = AppTheme.getStatusColor(c.status);

        return Scaffold(
          backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
              onPressed: () => Navigator.pop(context, true),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.claimNumber ?? c.id, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                Text('${c.claimType ?? 'Claim'} • ${c.tenantCode}', style: TextStyle(color: labelColor, fontSize: 12)),
              ],
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withAlpha(80)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(c.status.replaceAll('_', ' '), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                ]),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => provider.load(widget.claimId),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // ── CLAIM INFORMATION ────────────────────────
                  _Card(title: 'Claim Information', icon: Icons.description_outlined, cardColor: cardColor, borderColor: borderColor, children: [
                    _Row('Claim Type', c.claimType ?? 'N/A', labelColor, textColor),
                    _Row('Amount', _inrFormat.format(c.claimAmount), labelColor, textColor),
                    if (c.description != null && c.description!.isNotEmpty)
                      _Row('Description', c.description!, labelColor, textColor),
                    _Row('Submitted', _fmtDate(c.createdAt), labelColor, textColor),
                    _Row('Updated', _fmtDate(c.updatedAt), labelColor, textColor),
                  ]),
                  const SizedBox(height: 16),

                  // ── POLICY & VEHICLE DETAILS ─────────────────────
                  _Card(
                    title: 'Policy & Vehicle Information',
                    icon: Icons.shield_outlined,
                    iconColor: AppTheme.primaryBlue,
                    cardColor: cardColor,
                    borderColor: borderColor,
                    children: [
                      _Row('Policy Number', c.policyNumber, labelColor, textColor),
                      if (c.planName != null && c.planName!.isNotEmpty)
                        _Row('Plan Name', c.planName!, labelColor, textColor),
                      if (c.vehicleNumber != null && c.vehicleNumber!.isNotEmpty)
                        _Row('Vehicle Reg', c.vehicleNumber!, labelColor, textColor),
                      if (c.vehicleMakeModel != null && c.vehicleMakeModel!.isNotEmpty)
                        _Row('Make / Model', c.vehicleMakeModel!, labelColor, textColor),
                      if (c.insuredDeclaredValue != null && c.insuredDeclaredValue! > 0)
                        _Row('Insured Value (IDV)', _inrFormat.format(c.insuredDeclaredValue!), labelColor, textColor),
                      if (c.policyStartDate != null)
                        _Row('Coverage Start', _fmtDate(c.policyStartDate), labelColor, textColor),
                      if (c.policyEndDate != null)
                        _Row('Coverage End', _fmtDate(c.policyEndDate), labelColor, textColor),
                      if (c.policyStatus != null)
                        _Row('Policy Status', c.policyStatus!, labelColor, textColor),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── INCIDENT DETAILS ─────────────────────────
                  _Card(title: 'Incident Details', icon: Icons.location_on_outlined, cardColor: cardColor, borderColor: borderColor, children: [
                    _Row('Incident Date', _fmtDate(c.incidentDate), labelColor, textColor),
                    _Row('Address', c.incidentAddress ?? 'N/A', labelColor, textColor),
                    _Row('City', c.incidentCity ?? 'N/A', labelColor, textColor),
                    _Row('State', c.incidentState ?? 'N/A', labelColor, textColor),
                  ]),
                  const SizedBox(height: 16),

                  // ── INVESTIGATOR ─────────────────────────────
                  if (provider.hasInvestigator) ...[
                    _Card(
                      title: 'Investigator',
                      icon: Icons.person_search_outlined,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.badge_outlined, color: AppTheme.primaryBlue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Investigator: ${c.assignedInvestigatorName}',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (provider.investigatorReviewDone) ...[
                          Text(
                            'Investigation Review:',
                            style: TextStyle(
                              color: labelColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.warningAmber.withAlpha(15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.warningAmber.withAlpha(60)),
                            ),
                            child: Text(
                              c.reviewNotes!,
                              style: TextStyle(color: textColor, fontSize: 14, height: 1.4),
                            ),
                          ),
                          if (c.fraudStatus != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text('Fraud Assessment: ', style: TextStyle(color: labelColor, fontSize: 12)),
                                _FraudBadge(fraudStatus: c.fraudStatus!),
                              ],
                            ),
                          ],
                        ] else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : Colors.grey[300]!,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Text('⏳ ', style: TextStyle(fontSize: 15)),
                                Text(
                                  'Review not given yet',
                                  style: TextStyle(
                                    color: labelColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── DOCUMENTS ────────────────────────────────
                  Text('Documents (${provider.documents.length})',
                      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (provider.documents.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
                      child: Center(child: Text('No documents attached.', style: TextStyle(color: labelColor))),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5,
                      ),
                      itemCount: provider.documents.length,
                      itemBuilder: (_, idx) {
                        final doc = provider.documents[idx];
                        return _DocumentTile(
                          doc: doc,
                          cleanType: _cleanType,
                          fmtSize: _fmtSize,
                          cardColor: cardColor,
                          labelColor: labelColor,
                          textColor: textColor,
                          onView: () => _viewDocument(doc),
                          onDownload: () => _downloadDocument(doc),
                        );
                      },
                    ),
                  const SizedBox(height: 16),

                  // ── ADMIN DECISION ───────────────────────────
                  if (provider.hasDecision)
                    _Card(
                      title: 'Admin Decision',
                      icon: c.status == 'APPROVED' ? Icons.check_circle_outline : Icons.cancel_outlined,
                      iconColor: c.status == 'APPROVED' ? AppTheme.successGreen : AppTheme.dangerRed,
                      cardColor: c.status == 'APPROVED' ? AppTheme.successGreen.withAlpha(15) : AppTheme.dangerRed.withAlpha(15),
                      borderColor: c.status == 'APPROVED' ? AppTheme.successGreen.withAlpha(80) : AppTheme.dangerRed.withAlpha(80),
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: (c.status == 'APPROVED' ? AppTheme.successGreen : AppTheme.dangerRed).withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(c.status, style: TextStyle(
                            color: c.status == 'APPROVED' ? AppTheme.successGreen : AppTheme.dangerRed,
                            fontWeight: FontWeight.bold,
                          )),
                        ),
                        if (c.decisionNotes != null && c.decisionNotes!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('Decision Notes:', style: TextStyle(color: labelColor, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(c.decisionNotes!, style: TextStyle(color: textColor, fontSize: 14, height: 1.4)),
                        ],
                      ],
                    )
                  else
                    _Card(
                      title: 'Admin Decision',
                      icon: Icons.gavel_outlined,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      children: [
                        if (!provider.canMakeDecision) ...[
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.warningAmber.withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.warningAmber.withAlpha(80)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: AppTheme.warningAmber, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Decision Gated: Waiting for investigator review to be submitted before decision can be finalized.',
                                    style: TextStyle(
                                      color: AppTheme.warningAmber,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        TextFormField(
                          controller: _decisionNotesController,
                          maxLines: 3,
                          enabled: !provider.isProcessing && provider.canMakeDecision,
                          decoration: InputDecoration(
                            labelText: 'Decision Notes',
                            hintText: 'Enter approval or rejection reason...',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.successGreen,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: (provider.isProcessing || !provider.canMakeDecision)
                                  ? null
                                  : () => _handleDecision(context, true),
                              icon: provider.isProcessing
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.check_circle_outline),
                              label: const Text('APPROVE'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.dangerRed,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: (provider.isProcessing || !provider.canMakeDecision)
                                  ? null
                                  : () => _handleDecision(context, false),
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('REJECT'),
                            ),
                          ),
                        ]),
                      ],
                    ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // FAB: only show when NO investigator assigned
          floatingActionButton: provider.hasInvestigator
              ? null
              : FloatingActionButton.extended(
                  heroTag: 'assign_inv_fab',
                  onPressed: () => _showAssignSheet(context),
                  backgroundColor: AppTheme.primaryBlue,
                  icon: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 22),
                  label: const Text('Assign Investigator', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
        );
      },
    );
  }
}

// ── Reusable section card ─────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color cardColor;
  final Color borderColor;
  final Color? iconColor;
  final List<Widget> children;

  const _Card({
    required this.title,
    required this.icon,
    required this.cardColor,
    required this.borderColor,
    this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: iconColor ?? (isDark ? Colors.grey[400] : const Color(0xFF64748B))),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }
}

// ── Key-value row ─────────────────────────────────────────────────────────────
class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color labelColor;
  final Color textColor;

  const _Row(this.label, this.value, this.labelColor, this.textColor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(label, style: TextStyle(color: labelColor, fontSize: 13))),
        Expanded(child: Text(value, style: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 14))),
      ]),
    );
  }
}

// ── Fraud status badge ────────────────────────────────────────────────────────
class _FraudBadge extends StatelessWidget {
  final String fraudStatus;
  const _FraudBadge({required this.fraudStatus});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (fraudStatus) {
      case 'SUSPECTED':   color = Colors.orange; break;
      case 'CONFIRMED':   color = AppTheme.dangerRed; break;
      case 'CLEAR':       color = AppTheme.successGreen; break;
      default:            color = Colors.grey; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withAlpha(80))),
      child: Text(fraudStatus.replaceAll('_', ' '), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

// ── Document tile (Upgraded Modern Card) ──────────────────────────────────────
class _DocumentTile extends StatelessWidget {
  final DocumentModel doc;
  final String Function(String) cleanType;
  final String Function(int?) fmtSize;
  final Color cardColor;
  final Color labelColor;
  final Color textColor;
  final VoidCallback onView;
  final VoidCallback onDownload;

  const _DocumentTile({
    required this.doc,
    required this.cleanType,
    required this.fmtSize,
    required this.cardColor,
    required this.labelColor,
    required this.textColor,
    required this.onView,
    required this.onDownload,
  });

  IconData _getIcon(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif')) {
      return Icons.image_rounded;
    }
    if (lower.endsWith('.doc') || lower.endsWith('.docx') || lower.endsWith('.txt')) {
      return Icons.description_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Color _getAccentColor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return const Color(0xFFEF4444);
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp')) {
      return const Color(0xFF3B82F6);
    }
    if (lower.endsWith('.doc') || lower.endsWith('.docx') || lower.endsWith('.txt')) {
      return const Color(0xFF6366F1);
    }
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = _getAccentColor(doc.fileName);
    final iconData = _getIcon(doc.fileName);
    final formattedSize = fmtSize(doc.fileSize);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, size: 20, color: accentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cleanType(doc.documentType),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    if (formattedSize.isNotEmpty)
                      Text(
                        formattedSize,
                        style: TextStyle(color: labelColor, fontSize: 10),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            doc.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: labelColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onView,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 14,
                          color: isDark ? Colors.tealAccent : Colors.teal[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'View',
                          style: TextStyle(
                            color: isDark ? Colors.tealAccent : Colors.teal[700],
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
                  onTap: onDownload,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withAlpha(60),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download_rounded, size: 14, color: AppTheme.primaryBlue),
                        SizedBox(width: 4),
                        Text(
                          'Save',
                          style: TextStyle(
                            color: AppTheme.primaryBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

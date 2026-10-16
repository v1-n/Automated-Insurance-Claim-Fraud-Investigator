import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../../models/claim_model.dart';
import '../../models/document_model.dart';
import '../../providers/investigator_claims_provider.dart';
import '../../services/document_service.dart';
import '../../theme/app_theme.dart';

class InvestigationDetailScreen extends StatefulWidget {
  final String claimId;
  const InvestigationDetailScreen({super.key, required this.claimId});

  @override
  State<InvestigationDetailScreen> createState() => _InvestigationDetailScreenState();
}

class _InvestigationDetailScreenState extends State<InvestigationDetailScreen> {
  final DocumentService _documentService = DocumentService();
  final _inrFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  ClaimModel? _claim;
  List<DocumentModel> _documents = [];
  bool _isLoading = true;
  bool _isSubmittingReview = false;

  String _selectedFraudStatus = 'CLEAR';
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDetails();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final provider = context.read<InvestigatorClaimsProvider>();
      await provider.fetchClaimDetails(widget.claimId);
      if (!mounted) return;
      final claim = provider.selectedClaim;
      if (claim != null) {
        setState(() {
          _claim = claim;
          _documents = claim.documents;
          _notesController.text = claim.reviewNotes ?? '';
          _selectedFraudStatus = (claim.fraudStatus != null && claim.fraudStatus != 'PENDING_ANALYSIS')
              ? claim.fraudStatus!
              : 'CLEAR';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
        bytes = await _documentService.viewInvestigatorDocument(doc.id);
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
    final messenger = ScaffoldMessenger.of(context);
    if (doc.id.isEmpty && (doc.fileUrl == null || !doc.fileUrl!.startsWith('http'))) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Document ID is missing. Cannot download document from server.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    try {
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
                  'Downloading ${doc.fileName}...',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.primaryBlue,
          duration: const Duration(seconds: 1),
        ),
      );

      List<int> bytes;
      try {
        bytes = await _documentService.downloadInvestigatorDocument(doc.id);
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

  Future<void> _submitReview() async {
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter investigation review notes.')),
      );
      return;
    }

    setState(() => _isSubmittingReview = true);
    try {
      final provider = context.read<InvestigatorClaimsProvider>();
      final updated = await provider.submitReview(
        claimId: widget.claimId,
        fraudStatus: _selectedFraudStatus,
        reviewNotes: _notesController.text.trim(),
      );

      if (!mounted) return;
      if (updated != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Investigation review submitted!'), backgroundColor: AppTheme.successGreen),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(provider.errorMessage ?? 'Submission failed');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Review submission failed: ${e.toString()}'), backgroundColor: AppTheme.dangerRed),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return 'N/A';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('MMM dd, yyyy • hh:mm a').format(dt);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey[200]!;
    final labelColor = Colors.grey[500]!;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Loading Case...', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
      );
    }

    if (_claim == null) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('Case Error', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.dangerRed),
              const SizedBox(height: 16),
              Text('Claim not found.', style: TextStyle(color: textColor, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    final riskColor = AppTheme.getRiskColor(_claim!.fraudScore);
    final statusColor = AppTheme.getStatusColor(_claim!.status);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_claim!.claimNumber ?? _claim!.id, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${_claim!.claimType ?? "General"} Claim', style: TextStyle(color: labelColor, fontSize: 12)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withAlpha(60)),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _claim!.status.replaceAll('_', ' '),
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDetails,
        color: AppTheme.primaryBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── AI FRAUD RISK GAUGE ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 90,
                          width: 90,
                          child: CircularProgressIndicator(
                            value: _claim!.fraudScore / 100.0,
                            strokeWidth: 8,
                            backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey[200],
                            color: riskColor,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_claim!.fraudScore.toInt()}%',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            Text(
                              'RISK',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: labelColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Fraud Analysis',
                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _claim!.fraudScore >= 70
                                ? 'High probability of fraud matching standard patterns.'
                                : _claim!.fraudScore >= 40
                                    ? 'Moderate level of concerns. Manual inspection needed.'
                                    : 'Lower probability of fraud. Standard verification.',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── CLAIMANT & POLICY CARD ──
              _DetailCard(
                title: 'Policyholder & Incident Summary',
                icon: Icons.shield_outlined,
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                children: [
                  _DetailRow('Claimant Name', _claim!.policyHolderName ?? _claim!.customerName ?? 'N/A', labelColor, textColor),
                  _DetailRow('Claimant Email', _claim!.customerEmail ?? 'N/A', labelColor, textColor),
                  _DetailRow('Policy Number', _claim!.policyNumber, labelColor, textColor),
                  if (_claim!.planName != null && _claim!.planName!.isNotEmpty)
                    _DetailRow('Plan Name', _claim!.planName!, labelColor, textColor),
                  if (_claim!.vehicleNumber != null && _claim!.vehicleNumber!.isNotEmpty)
                    _DetailRow('Vehicle Reg', _claim!.vehicleNumber!, labelColor, textColor),
                  if (_claim!.vehicleMakeModel != null && _claim!.vehicleMakeModel!.isNotEmpty)
                    _DetailRow('Make / Model', _claim!.vehicleMakeModel!, labelColor, textColor),
                  if (_claim!.insuredDeclaredValue != null && _claim!.insuredDeclaredValue! > 0)
                    _DetailRow('Insured Value (IDV)', _inrFormat.format(_claim!.insuredDeclaredValue!), labelColor, textColor),
                  if (_claim!.policyStartDate != null)
                    _DetailRow('Coverage Period', '${_fmtDate(_claim!.policyStartDate)} - ${_fmtDate(_claim!.policyEndDate)}', labelColor, textColor),
                  _DetailRow('Claim Amount', _inrFormat.format(_claim!.claimAmount), labelColor, textColor),
                  _DetailRow('Category', _claim!.claimType ?? 'General', labelColor, textColor),
                  if (_claim!.incidentDate != null)
                    _DetailRow('Incident Date', _fmtDate(_claim!.incidentDate), labelColor, textColor),
                  _DetailRow('Incident Location', _claim!.incidentLocation, labelColor, textColor),
                  const SizedBox(height: 12),
                  Text('Incident Description:', style: TextStyle(color: labelColor, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(
                    _claim!.description ?? 'No description provided.',
                    style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── EVIDENCE DOCUMENTS CARD ──
              _DetailCard(
                title: 'Evidence Files (${_documents.length})',
                icon: Icons.folder_zip_outlined,
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                children: [
                  if (_documents.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No uploaded evidence files found.', style: TextStyle(color: labelColor, fontSize: 13)),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _documents.length,
                      separatorBuilder: (context, index) => Divider(color: borderColor, height: 1),
                      itemBuilder: (context, idx) {
                        final doc = _documents[idx];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => _viewDocument(doc),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withAlpha(15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.description_outlined, color: AppTheme.primaryBlue, size: 20),
                          ),
                          title: Text(
                            doc.fileName,
                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            doc.documentType.replaceAll('_', ' '),
                            style: TextStyle(color: labelColor, fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, color: AppTheme.primaryBlue),
                                onPressed: () => _viewDocument(doc),
                                tooltip: 'View document',
                              ),
                              IconButton(
                                icon: const Icon(Icons.download_rounded, color: AppTheme.primaryBlue),
                                onPressed: () => _downloadDocument(doc),
                                tooltip: 'Download file',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // ── INVESTIGATION REVIEW FINDINGS SUBMISSION ──
              _DetailCard(
                title: 'Investigation Findings',
                icon: Icons.rate_review_outlined,
                cardColor: cardColor,
                borderColor: borderColor,
                textColor: textColor,
                children: [
                  if (!_claim!.reviewAllowed) ...[
                    // Review already submitted
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.successGreen.withAlpha(30)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppTheme.successGreen, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Investigation review already submitted successfully.',
                              style: TextStyle(color: AppTheme.successGreen, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(
                      'Fraud Status Assessed',
                      _selectedFraudStatus.replaceAll('_', ' '),
                      labelColor,
                      _selectedFraudStatus == 'CLEAR'
                          ? AppTheme.successGreen
                          : _selectedFraudStatus == 'CONFIRMED'
                              ? AppTheme.dangerRed
                              : AppTheme.warningAmber,
                    ),
                    const SizedBox(height: 12),
                    Text('Investigation Review Notes:', style: TextStyle(color: labelColor, fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(
                      _claim!.reviewNotes ?? 'No notes provided.',
                      style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
                    ),
                  ] else ...[
                    // Form to review
                    DropdownButtonFormField<String>(
                      initialValue: _selectedFraudStatus,
                      dropdownColor: cardColor,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'Assessed Fraud Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'CLEAR', child: Text('CLEAR (Low/No Risk)')),
                        DropdownMenuItem(value: 'SUSPECTED', child: Text('SUSPECTED (Medium Risk)')),
                        DropdownMenuItem(value: 'CONFIRMED', child: Text('CONFIRMED (High Risk)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedFraudStatus = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 4,
                      style: TextStyle(color: textColor),
                      decoration: const InputDecoration(
                        labelText: 'Investigation Findings & Notes',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                        hintText: 'Enter detailed findings, witness details, or reasoning...',
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmittingReview ? null : _submitReview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isSubmittingReview
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'SUBMIT INVESTIGATION REVIEW',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final List<Widget> children;

  const _DetailCard({
    required this.title,
    required this.icon,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryBlue, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;

  const _DetailRow(this.label, this.value, this.labelColor, this.valueColor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

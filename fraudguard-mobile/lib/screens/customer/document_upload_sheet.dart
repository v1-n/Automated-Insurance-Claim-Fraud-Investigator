import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/document_service.dart';
import '../../theme/app_theme.dart';

class PickedDocument {
  final String filePath;
  final String fileName;
  final String documentType;

  PickedDocument({
    required this.filePath,
    required this.fileName,
    required this.documentType,
  });
}

class DocumentUploadSheet extends StatefulWidget {
  final String? claimId; // If null, we return the picked files instead of uploading them
  final Function(List<PickedDocument>)? onFilesPicked; // For SubmitClaimScreen
  final VoidCallback? onUploadSuccess; // For ClaimDetailScreen

  const DocumentUploadSheet({
    super.key,
    this.claimId,
    this.onFilesPicked,
    this.onUploadSuccess,
  });

  @override
  State<DocumentUploadSheet> createState() => _DocumentUploadSheetState();
}

class _DocumentUploadSheetState extends State<DocumentUploadSheet> {
  final DocumentService _documentService = DocumentService();
  final ImagePicker _imagePicker = ImagePicker();

  String _selectedDocType = 'ACCIDENT_PHOTO';
  final List<File> _selectedFiles = [];
  bool _isUploading = false;

  final Map<String, String> _docTypes = {
    'ACCIDENT_PHOTO': 'Accident Photo',
    'FIR': 'FIR (First Information Report)',
    'VEHICLE_DOCUMENT': 'Vehicle Document',
    'POLICY_DOCUMENT': 'Policy Document',
    'MEDICAL_REPORT': 'Medical Report',
    'REPAIR_ESTIMATE': 'Repair Estimate',
    'INVOICE': 'Invoice',
    'OTHER': 'Other Document',
  };

  Future<void> _captureFromCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() {
          _selectedFiles.add(File(photo.path));
        });
      }
    } catch (e) {
      _showSnackBar('Failed to capture photo: $e', AppTheme.dangerRed);
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          for (var file in result.files) {
            if (file.path != null) {
              _selectedFiles.add(File(file.path!));
            }
          }
        });
      }
    } catch (e) {
      _showSnackBar('Failed to select files: $e', AppTheme.dangerRed);
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
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

  Future<void> _handleConfirm() async {
    if (_selectedFiles.isEmpty) {
      _showSnackBar('Please select at least one document or photo.', AppTheme.dangerRed);
      return;
    }

    final pickedDocs = _selectedFiles.map((f) {
      final fileName = f.path.split('/').last;
      return PickedDocument(
        filePath: f.path,
        fileName: fileName,
        documentType: _selectedDocType,
      );
    }).toList();

    if (widget.claimId == null) {
      // Return files to parent screen (SubmitClaimScreen)
      if (widget.onFilesPicked != null) {
        widget.onFilesPicked!(pickedDocs);
      }
      Navigator.pop(context);
    } else {
      // Upload immediately for ClaimDetailScreen
      setState(() => _isUploading = true);
      try {
        int successCount = 0;
        for (var doc in pickedDocs) {
          await _documentService.uploadDocument(
            claimId: widget.claimId!,
            filePath: doc.filePath,
            documentType: doc.documentType,
          );
          successCount++;
        }

        if (mounted) {
          _showSnackBar(
            'Successfully uploaded $successCount document(s)!',
            AppTheme.successGreen,
          );
          if (widget.onUploadSuccess != null) {
            widget.onUploadSuccess!();
          }
          Navigator.pop(context);
        }
      } catch (e) {
        _showSnackBar('Upload failed: $e', AppTheme.dangerRed);
      } finally {
        if (mounted) {
          setState(() => _isUploading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[600] : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.claimId != null ? 'Upload Documents' : 'Attach Evidence',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Document Type Selection
          DropdownButtonFormField<String>(
            initialValue: _selectedDocType,
            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Document Type',
              labelStyle: TextStyle(color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: _docTypes.entries.map((entry) {
              return DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value),
              );
            }).toList(),
            onChanged: _isUploading
                ? null
                : (val) {
                    if (val != null) {
                      setState(() => _selectedDocType = val);
                    }
                  },
          ),
          const SizedBox(height: 16),

          // Source buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _captureFromCamera,
                  icon: Icon(Icons.camera_alt_outlined, color: isDark ? Colors.white : const Color(0xFF0F172A), size: 20),
                  label: Text('Camera', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _pickFiles,
                  icon: Icon(Icons.upload_file_outlined, color: isDark ? Colors.white : const Color(0xFF0F172A), size: 20),
                  label: Text('Upload File', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Selected Files List
          if (_selectedFiles.isNotEmpty) ...[
            Text(
              'Selected Files',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _selectedFiles.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final file = _selectedFiles[index];
                  final name = file.path.split('/').last;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          child: Text(
                            name,
                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!_isUploading)
                          IconButton(
                            icon: const Icon(Icons.close, color: AppTheme.dangerRed, size: 18),
                            onPressed: () => _removeFile(index),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Confirm Action Button
          ElevatedButton(
            onPressed: _isUploading ? null : _handleConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isUploading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    widget.claimId != null ? 'UPLOAD DOCUMENTS' : 'ATTACH FILES',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

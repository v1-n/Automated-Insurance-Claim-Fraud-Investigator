class DocumentModel {
  final String id;
  final String fileName;
  final String documentType;
  final String? fileUrl;
  final String? uploadedAt;
  final int? fileSize;

  DocumentModel({
    required this.id,
    required this.fileName,
    required this.documentType,
    this.fileUrl,
    this.uploadedAt,
    this.fileSize,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: (json['documentId'] ?? json['claimDocId'] ?? json['docId'] ?? json['id'])?.toString() ?? '',
      fileName: json['originalFileName'] ?? json['fileName'] ?? json['originalName'] ?? 'Document',
      documentType: json['documentType'] ?? 'OTHER',
      fileUrl: json['fileUrl'] ?? json['cloudinaryUrl'],
      uploadedAt: json['uploadedAt']?.toString() ?? json['createdAt']?.toString(),
      fileSize: json['fileSize'] as int?,
    );
  }
}

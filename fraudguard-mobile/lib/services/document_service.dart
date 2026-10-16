import '../core/network/api_client.dart';
import '../models/document_model.dart';

class DocumentService {
  final ApiClient _api = ApiClient();

  Future<List<DocumentModel>> getClaimDocuments(String claimId) async {
    final response = await _api.get('/claims/$claimId/documents');
    if (response is List) {
      return response.map((item) => DocumentModel.fromJson(item)).toList();
    }
    return [];
  }

  Future<DocumentModel> uploadDocument({
    required String claimId,
    required String filePath,
    required String documentType,
  }) async {
    final response = await _api.uploadMultipart(
      '/claims/$claimId/documents',
      filePath: filePath,
      fileParamName: 'file',
      fields: {'documentType': documentType},
    );
    return DocumentModel.fromJson(response);
  }

  Future<void> deleteDocument(String documentId) async {
    await _api.delete('/documents/$documentId');
  }

  // ============================================================
  // INVESTIGATOR - VIEW DOCUMENT
  // ============================================================
  Future<List<int>> viewInvestigatorDocument(String documentId) async {
    final response = await _api.getRaw('/investigator/documents/$documentId/view');
    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      return response.bodyBytes;
    }
    throw Exception('Failed to view document. Status: ${response.statusCode}');
  }

  // ============================================================
  // INVESTIGATOR - DOWNLOAD DOCUMENT
  // ============================================================
  Future<List<int>> downloadInvestigatorDocument(String documentId) async {
    final response = await _api.getRaw('/investigator/documents/$documentId/view');
    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      return response.bodyBytes;
    }
    throw Exception('Failed to download document. Status: ${response.statusCode}');
  }

  // ============================================================
  // ADMIN - DOWNLOAD / VIEW DOCUMENT
  // ============================================================
  Future<List<int>> downloadAdminDocument(String documentId) async {
    final response = await _api.getRaw('/admin/documents/$documentId/download');
    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      return response.bodyBytes;
    }
    throw Exception('Failed to fetch admin document. Status: ${response.statusCode}');
  }

  // ============================================================
  // GENERIC FALLBACK
  // ============================================================
  Future<List<int>> downloadDocument(String documentId) async {
    try {
      return await downloadAdminDocument(documentId);
    } catch (_) {}
    try {
      return await viewInvestigatorDocument(documentId);
    } catch (_) {}
    final response = await _api.getRaw('/documents/$documentId/download');
    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      return response.bodyBytes;
    }
    throw Exception('Failed to fetch document (access denied or not found on server).');
  }
}

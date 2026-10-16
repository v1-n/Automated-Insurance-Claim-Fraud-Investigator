import api from "./api";

/**
 * Upload a document for a claim.
 * Sends multipart/form-data: file + documentType (DocumentType enum name)
 */
export const uploadDocument = (claimId, file, documentType) => {
  const formData = new FormData();
  formData.append("file", file);
  formData.append("documentType", documentType);

  return api.post(`/claims/${claimId}/documents`, formData, {
    headers: { "Content-Type": "multipart/form-data" },
  });
};

/** Get all documents for a claim */
export const getClaimDocuments = (claimId) =>
  api.get(`/claims/${claimId}/documents`);

/** Delete a document by its ID */
export const deleteDocument = (documentId) =>
  api.delete(`/documents/${documentId}`);

/** Download a document — returns a blob URL you can open/save */
export const downloadDocument = (documentId) =>
  api.get(`/documents/${documentId}/download`, { responseType: "blob" });

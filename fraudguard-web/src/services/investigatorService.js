import api from "./api";

/** Get assigned claims for investigator */
export const getAssignedClaims = (pageNo = 0, pageSize = 10, sortBy = "CREATED_AT", sortDir = "DESC") =>
  api.get("/investigator/claims", {
    params: { pageNumber: pageNo, pageSize, sortBy, sortDir },
  });

/** Get full details of a specific claim assigned to the investigator */
export const getClaimDetails = (claimId) =>
  api.get(`/investigator/claims/${claimId}`);

/** Review a claim */
export const reviewClaim = (claimId, reviewData) =>
  api.patch(`/investigator/claims/${claimId}/review`, reviewData);

/** View a claim document URL */
export const viewDocument = (documentId) =>
  api.get(`/investigator/documents/${documentId}/view`, { responseType: "blob" });

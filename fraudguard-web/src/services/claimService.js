import api from "./api";

/**
 * Fetch claims for the current user.
 * @param pageNo    - 0-based page index (backend param name: pageNo)
 * @param pageSize  - items per page
 * @param sortBy    - ClaimSortField enum name: CREATED_AT | CLAIM_AMOUNT | INCIDENT_DATE | CLAIM_STATUS
 * @param sortDir   - ASC | DESC
 */
export const getAllClaims = (pageNo = 0, pageSize = 10, sortBy = "CREATED_AT", sortDir = "DESC") => {
  return api.get("/claims/my", {
    params: { pageNumber: pageNo, pageSize, sortBy, sortDir },
  });
};

export const getAllUnsignedClaims = () => {
  return api.get("admin/claims/unassigned");
};


// alias for backward compatibility
export const getMyClaim = getAllClaims;

export const getClaimById = (claimId) => api.get(`/claims/${claimId}`);
export   const addClaim     = (payload)  => api.post("/claims", payload);

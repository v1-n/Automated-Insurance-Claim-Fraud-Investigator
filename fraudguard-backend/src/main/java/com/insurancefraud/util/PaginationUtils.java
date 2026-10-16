package com.insurancefraud.util;

import com.insurancefraud.enums.ClaimSortField;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
public class PaginationUtils {

    public  static Pageable buildPageable(
            int pageNumber, 
            int pageSize,
            ClaimSortField sortBy, 
            String sortDir
    ){
        pageSize = Math.max(1, Math.min(pageSize, 50));
        Sort sort=sortDir.equalsIgnoreCase("ASC")
                        ? Sort.by(sortBy.getFieldName()).ascending()
                        : Sort.by(sortBy.getFieldName()).descending();

        return PageRequest.of(pageNumber, pageSize, sort);
    }

}
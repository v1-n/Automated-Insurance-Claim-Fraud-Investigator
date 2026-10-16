package com.insurancefraud.admin.dto;

import com.insurancefraud.enums.UserStatus;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;

@Setter
@Getter
@AllArgsConstructor
public class InvestigatorsWorkloadResDto {
       private Long investigatorId;
       private String fullName;
       private String email;
       private UserStatus status;
       private Long reviewsCompleted;
       private Long activeClaims;


}

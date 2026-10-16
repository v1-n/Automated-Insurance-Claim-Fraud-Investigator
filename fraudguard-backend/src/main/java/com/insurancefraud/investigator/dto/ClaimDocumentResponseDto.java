package com.insurancefraud.investigator.dto;

import lombok.*;

@Data
@AllArgsConstructor
@NoArgsConstructor
@Getter
@Setter
public class ClaimDocumentResponseDto {

    private Long documentId;

    private String fileName;

    private String documentType;

}
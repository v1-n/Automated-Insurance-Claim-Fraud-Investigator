package com.insurancefraud.enums;

import lombok.Getter;

@Getter
public enum SupportedDocumentType {
    PDF("application/pdf"),
    PNG("image/png"),
    JPG("image/jpeg"),
    JPEG("image/jpeg");

    private final String mimeType;

    SupportedDocumentType(String mimeType) {
        this.mimeType=mimeType;
    }

    // Helper method to validate incoming strings
    public static boolean isValidMimeType(String type){
        for (SupportedDocumentType docType: SupportedDocumentType.values()){
            if(docType.getMimeType().equalsIgnoreCase(type)){
                return true;
            }
        }
        return false;
    }


}

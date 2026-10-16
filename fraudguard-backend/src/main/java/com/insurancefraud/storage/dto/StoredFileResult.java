package com.insurancefraud.storage.dto;

import com.insurancefraud.enums.StorageProvider;
import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public class StoredFileResult {
   private String fileUrl;
   private String storageKey;
   private StorageProvider provider;
   private String originalName;
   private String mimeType;
   private long fileSize;
}
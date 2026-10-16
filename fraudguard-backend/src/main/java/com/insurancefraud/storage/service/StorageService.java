package com.insurancefraud.storage.service;

import com.insurancefraud.entity.Claim;
import com.insurancefraud.storage.dto.StoredFileResult;
import org.springframework.core.io.Resource;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
public interface StorageService {

    StoredFileResult storeFile(
            MultipartFile file,
            Claim claim
    ) throws IOException;

    Resource downloadFile(String fileUrl);

  //  void deleteFile(String storageKey) throws IOException;
}
package com.insurancefraud.storage.service.impl;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import com.insurancefraud.common.exception.ResourceNotFoundException;
import com.insurancefraud.entity.Claim;
import com.insurancefraud.enums.StorageProvider;
import com.insurancefraud.storage.dto.StoredFileResult;
import com.insurancefraud.storage.service.StorageService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.net.MalformedURLException;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
@ConditionalOnProperty(name = "storage.provider", havingValue = "cloudinary")
public class CloudinaryStorageService implements StorageService {

    private final Cloudinary cloudinary;

    @Override
    public StoredFileResult storeFile(MultipartFile file, Claim claim)
            throws IOException {

        log.info("Uploading file '{}' to Cloudinary for claim '{}'...",
                file.getOriginalFilename(), claim.getClaimNumber());

        Map<?, ?> uploadResult = cloudinary.uploader().upload(
                file.getBytes(),
                ObjectUtils.asMap(
                        "folder",
                        "insurance-fraud/"
                                + claim.getTenant().getTenantCode()
                                + "/"
                                + claim.getClaimNumber(),
                        "resource_type", "auto"
                )
        );

        String secureUrl = uploadResult.get("secure_url").toString();
        String publicId = uploadResult.get("public_id").toString();

        log.info("Successfully uploaded to Cloudinary! Public ID: {}, URL: {}", publicId, secureUrl);

        return new StoredFileResult(
                secureUrl,
                publicId,
                StorageProvider.CLOUDINARY,
                file.getOriginalFilename(),
                file.getContentType(),
                file.getSize()
        );
    }

    @Override
    public Resource downloadFile(String fileUrl) {
        try {
            String downloadUrl = fileUrl;

            if (fileUrl != null && fileUrl.contains("cloudinary.com")) {
                downloadUrl = getSignedCloudinaryUrl(fileUrl);
            }

            log.info("Downloading file via Cloudinary signed URL: {}", downloadUrl);
            return new UrlResource(downloadUrl);
        } catch (MalformedURLException e) {
            log.error("Invalid Cloudinary file URL {}: {}", fileUrl, e.getMessage());
            throw new ResourceNotFoundException("Invalid file URL: " + fileUrl);
        }
    }

    private String getSignedCloudinaryUrl(String fileUrl) {
        try {
            String[] parts = fileUrl.split("/upload/");
            if (parts.length < 2) return fileUrl;

            String prefix = parts[0];
            String resourceType = prefix.substring(prefix.lastIndexOf("/") + 1);

            String pathWithVersion = parts[1];
            String publicIdWithPath = pathWithVersion.replaceFirst("^v\\d+/", "");

            return cloudinary.url()
                    .resourceType(resourceType)
                    .signed(true)
                    .generate(publicIdWithPath);
        } catch (Exception e) {
            log.warn("Could not generate signed Cloudinary URL: {}. Falling back to original URL.", e.getMessage());
            return fileUrl;
        }
    }
}




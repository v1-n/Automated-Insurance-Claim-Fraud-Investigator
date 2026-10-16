package com.insurancefraud.storage.service.impl;

import com.insurancefraud.common.exception.InvalidFileException;
import com.insurancefraud.common.exception.ResourceNotFoundException;
import com.insurancefraud.entity.Claim;
import com.insurancefraud.enums.StorageProvider;
import com.insurancefraud.storage.dto.StoredFileResult;
import com.insurancefraud.storage.service.StorageService;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.stereotype.Service;
import org.springframework.util.StreamUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.MalformedURLException;
import java.nio.file.*;
import java.time.LocalDate;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@ConditionalOnProperty(name = "storage.provider", havingValue = "local", matchIfMissing = true)
public class LocalStorageService implements StorageService {
    private final Path rootPath;

    private String getFileExtension(String fileName) {
        int lastDot = fileName.lastIndexOf('.');
        return lastDot == -1 ? "" : fileName.substring(lastDot + 1);
    }

    @Override
    public StoredFileResult storeFile(MultipartFile file, Claim claim) throws IOException {

        String originalFileName = file.getOriginalFilename();

        if (originalFileName == null || originalFileName.isBlank()) {
            throw new InvalidFileException("Invalid file name");
        }

        String extension = getFileExtension(originalFileName);
        String storedFileName = UUID.randomUUID() + (extension.isBlank() ? "" : "." + extension);

        LocalDate today = LocalDate.now();
        Path dateDirectory = rootPath.resolve(
                today.getYear()
                        + File.separator
                        + String.format("%02d", today.getMonthValue())
                        + File.separator
                        + String.format("%02d", today.getDayOfMonth())
        );

        Files.createDirectories(dateDirectory);
        Path filePath = dateDirectory.resolve(storedFileName);
        try (
                InputStream inputStream = file.getInputStream();
                OutputStream outputStream =
                        Files.newOutputStream(filePath, StandardOpenOption.CREATE_NEW)
        ) {
            StreamUtils.copy(inputStream, outputStream);
        }
        String storagePath= rootPath.relativize(filePath).toString();


        return new StoredFileResult(
                storagePath,
                storedFileName,
                StorageProvider.LOCAL,
                originalFileName,
                file.getContentType(),
                file.getSize());
    }


    @Override
    public Resource downloadFile(String fileUrl) {
        try {
            Path filePath = rootPath.resolve(fileUrl).normalize();
            if (!Files.exists(filePath) || !Files.isRegularFile(filePath)) {
                throw new ResourceNotFoundException("File not found");
            }
            return new UrlResource(filePath.toUri());
        } catch (MalformedURLException e) {
            throw new ResourceNotFoundException("Invalid file path");
        }
    }




}
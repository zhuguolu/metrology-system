package com.metrology.dto;

public record FileMetadataDto(
        Long id,
        String name,
        Long fileSize,
        String mimeType,
        String etag,
        String lastModified,
        Boolean supportsRange
) {
}

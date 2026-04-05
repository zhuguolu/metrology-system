package com.metrology.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(
        name = "user_files",
        indexes = {
                @Index(name = "idx_user_files_user_parent_type_name", columnList = "user_id, parent_id, type, name"),
                @Index(name = "idx_user_files_user_parent_name", columnList = "user_id, parent_id, name"),
                @Index(name = "idx_user_files_parent_type_name", columnList = "parent_id, type, name"),
                @Index(name = "idx_user_files_parent", columnList = "parent_id")
        }
)
@Data
@NoArgsConstructor
public class UserFile {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 100)
    private String userId;

    private Long parentId; // null = root

    @Column(nullable = false, length = 255)
    private String name;

    @Column(nullable = false, length = 10)
    private String type; // FOLDER, FILE

    @Column(name = "file_path", length = 500)
    private String filePath;

    @Column(name = "file_size")
    private Long fileSize;

    @Column(name = "mime_type", length = 100)
    private String mimeType;

    @Column(name = "share_token", length = 64, unique = true)
    private String shareToken;

    @Column(name = "share_password_hash", length = 255)
    private String sharePasswordHash;

    @Column(name = "share_expires_at")
    private LocalDateTime shareExpiresAt;

    @Column(name = "share_enabled")
    private Boolean shareEnabled;

    @Column(name = "share_allow_download")
    private Boolean shareAllowDownload;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Transient
    private Boolean readOnly;

    @Transient
    private Boolean shared;

    @Transient
    private Long grantRootId;

    @Transient
    private String sharedOwner;

    @PrePersist
    public void prePersist() {
        createdAt = LocalDateTime.now();
        if (shareEnabled == null) shareEnabled = false;
        if (shareAllowDownload == null) shareAllowDownload = true;
    }
}

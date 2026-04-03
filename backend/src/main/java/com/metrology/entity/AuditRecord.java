package com.metrology.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "audit_records")
@Data
@NoArgsConstructor
public class AuditRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 20)
    private String type;          // CREATE, UPDATE, DELETE

    @Column(name = "entity_type", nullable = false, length = 50)
    private String entityType;    // DEVICE

    @Column(name = "entity_id")
    private Long entityId;

    @Column(name = "submitted_by", nullable = false, length = 100)
    private String submittedBy;

    @Column(name = "submitted_at", nullable = false)
    private LocalDateTime submittedAt;

    @Column(nullable = false, length = 20)
    private String status = "PENDING"; // PENDING, APPROVED, REJECTED

    @Column(name = "approved_by", length = 100)
    private String approvedBy;

    @Column(name = "approved_at")
    private LocalDateTime approvedAt;

    @Column(name = "original_data", columnDefinition = "LONGTEXT")
    private String originalData;  // JSON snapshot of original (for UPDATE/DELETE)

    @Column(name = "new_data", columnDefinition = "LONGTEXT")
    private String newData;       // JSON snapshot of new state (for CREATE/UPDATE)

    @Column(columnDefinition = "TEXT")
    private String remark;        // submitter's note

    @Column(name = "reject_reason", columnDefinition = "TEXT")
    private String rejectReason;

    @PrePersist
    public void prePersist() {
        submittedAt = LocalDateTime.now();
        if (status == null) status = "PENDING";
    }
}

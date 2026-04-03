package com.metrology.repository;

import com.metrology.entity.AuditRecord;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface AuditRecordRepository extends JpaRepository<AuditRecord, Long> {

    List<AuditRecord> findByStatusOrderBySubmittedAtDesc(String status);

    List<AuditRecord> findBySubmittedByOrderBySubmittedAtDesc(String submittedBy);

    Page<AuditRecord> findAllByOrderBySubmittedAtDesc(Pageable pageable);

    long countByStatus(String status);
}

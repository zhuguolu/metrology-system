package com.metrology.repository;

import com.metrology.entity.AuditWorkflowStep;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface AuditWorkflowStepRepository extends JpaRepository<AuditWorkflowStep, Long> {

    List<AuditWorkflowStep> findByModuleNameOrderByStepOrderAsc(String moduleName);

    void deleteByModuleName(String moduleName);
}

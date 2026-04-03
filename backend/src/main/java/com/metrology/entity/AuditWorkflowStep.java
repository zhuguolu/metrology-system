package com.metrology.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "audit_workflow_steps")
@Data
@NoArgsConstructor
public class AuditWorkflowStep {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "module_name", nullable = false, length = 50)
    private String moduleName;    // e.g., "DEVICE"

    @Column(name = "step_order", nullable = false)
    private Integer stepOrder;

    @Column(name = "step_name", length = 100)
    private String stepName;

    @Column(name = "approver_type", length = 20)
    private String approverType;  // "ROLE" or "USER"

    @Column(name = "approver_value", length = 100)
    private String approverValue; // "ADMIN" or specific username
}

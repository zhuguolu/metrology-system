package com.metrology.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "devices", indexes = {
        @Index(name = "idx_devices_metric_no", columnList = "metric_no"),
        @Index(name = "idx_devices_asset_no", columnList = "asset_no"),
        @Index(name = "idx_devices_serial_no", columnList = "serial_no"),
        @Index(name = "idx_devices_dept", columnList = "dept"),
        @Index(name = "idx_devices_responsible_person", columnList = "responsible_person"),
        @Index(name = "idx_devices_use_status", columnList = "use_status"),
        @Index(name = "idx_devices_validity", columnList = "validity"),
        @Index(name = "idx_devices_next_date", columnList = "next_date"),
        @Index(name = "idx_devices_cal_date", columnList = "cal_date"),
        @Index(name = "idx_devices_todo_lookup", columnList = "use_status, validity, next_date"),
        @Index(name = "idx_devices_dept_next_date", columnList = "dept, next_date")
})
@Data
@NoArgsConstructor
public class Device {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 200)
    private String name;

    @Column(name = "metric_no", nullable = false, length = 100)
    private String metricNo;

    @Column(name = "asset_no", length = 100)
    private String assetNo;

    @Column(name = "abc_class", length = 10)
    private String abcClass;

    @Column(length = 100)
    private String dept;

    @Column(length = 200)
    private String location;

    private Integer cycle;

    @Column(name = "cal_date")
    private LocalDate calDate;

    @Column(name = "next_date")
    private LocalDate nextDate;

    @Column(length = 20)
    private String validity;

    @Column(name = "days_passed")
    private Integer daysPassed;

    @Column(length = 20)
    private String status = "正常";

    @Column(name = "use_status", length = 50)
    private String useStatus = "正常";

    @Column(columnDefinition = "TEXT")
    private String remark;

    @Column(name = "image_path", length = 500)
    private String imagePath;

    @Column(name = "image_name", length = 255)
    private String imageName;

    @Column(name = "image_path_2", length = 500)
    private String imagePath2;

    @Column(name = "image_name_2", length = 255)
    private String imageName2;

    @Column(name = "cert_path", length = 500)
    private String certPath;

    @Column(name = "cert_name", length = 255)
    private String certName;

    // ── 扩展字段 ──────────────────────────────────
    @Column(name = "serial_no", length = 100)
    private String serialNo;           // 出厂编号

    @Column(name = "purchase_price")
    private Double purchasePrice;      // 采购价格

    @Column(name = "purchase_date")
    private LocalDate purchaseDate;    // 采购时间

    @Column(name = "calibration_result", length = 200)
    private String calibrationResult;  // 校准结果判定

    @Column(name = "responsible_person", length = 100)
    private String responsiblePerson;  // 使用责任人

    @Column(name = "manufacturer", length = 200)
    private String manufacturer;       // 制造厂

    @Column(length = 100)
    private String model;              // 设备型号

    @Column(name = "graduation_value", length = 100)
    private String graduationValue;    // 分度值

    @Column(name = "test_range", length = 200)
    private String testRange;          // 测试范围

    @Column(name = "allowable_error", length = 100)
    private String allowableError;     // 仪器允许误差

    @Column(name = "created_by", length = 100)
    private String createdBy;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    public void prePersist() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
        if (status == null) status = "正常";
        if (useStatus == null) useStatus = "正常";
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}

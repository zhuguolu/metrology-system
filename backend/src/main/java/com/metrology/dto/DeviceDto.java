package com.metrology.dto;

import lombok.Data;

@Data
public class DeviceDto {
    private Long id;
    private String name;
    private String metricNo;
    private String assetNo;
    private String abcClass;
    private String dept;
    private String location;
    private Integer cycle;
    private String calDate;
    private String nextDate;
    private String validity;
    private Integer daysPassed;
    private String status;
    private String remark;
    private String imagePath;
    private String imageName;
    private String imagePath2;
    private String imageName2;
    private String certPath;
    private String certName;
    private String useStatus;

    // 扩展字段
    private String serialNo;           // 出厂编号
    private Double purchasePrice;      // 采购价格
    private String purchaseDate;       // 采购时间
    private String calibrationResult;  // 校准结果判定
    private String responsiblePerson;  // 使用责任人
    private String manufacturer;       // 制造厂
    private String model;              // 设备型号
    private String graduationValue;    // 分度值
    private String testRange;          // 测试范围
    private String allowableError;     // 仪器允许误差
    private Integer serviceLife;       // 使用年限（计算值，年）
}

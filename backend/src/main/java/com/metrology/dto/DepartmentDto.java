package com.metrology.dto;

import lombok.Data;
import java.util.ArrayList;
import java.util.List;

@Data
public class DepartmentDto {
    private Long id;
    private String name;
    private String code;
    private String description;
    private Integer sortOrder;
    private Long parentId;
    private List<DepartmentDto> children = new ArrayList<>();
}

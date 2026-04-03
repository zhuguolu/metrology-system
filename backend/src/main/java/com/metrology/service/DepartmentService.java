package com.metrology.service;

import com.metrology.dto.DepartmentDto;
import com.metrology.entity.Department;
import com.metrology.repository.DepartmentRepository;
import lombok.RequiredArgsConstructor;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class DepartmentService {

    private final DepartmentRepository deptRepository;

    public List<Department> getAll() {
        return deptRepository.findAllByOrderBySortOrderAscNameAsc();
    }

    public List<Department> getFiltered(String search) {
        List<Department> all = deptRepository.findAllByOrderBySortOrderAscNameAsc();
        if (search == null || search.isBlank()) return all;
        String kw = search.toLowerCase();
        return all.stream().filter(d ->
                (d.getName() != null && d.getName().toLowerCase().contains(kw)) ||
                (d.getCode() != null && d.getCode().toLowerCase().contains(kw)) ||
                (d.getDescription() != null && d.getDescription().toLowerCase().contains(kw))
        ).collect(Collectors.toList());
    }

    public List<DepartmentDto> getTree() {
        List<Department> all = deptRepository.findAllByOrderBySortOrderAscNameAsc();
        Map<Long, DepartmentDto> dtoMap = new LinkedHashMap<>();
        for (Department d : all) {
            DepartmentDto dto = toDto(d);
            dtoMap.put(d.getId(), dto);
        }
        List<DepartmentDto> roots = new ArrayList<>();
        for (Department d : all) {
            DepartmentDto dto = dtoMap.get(d.getId());
            if (d.getParentId() == null) {
                roots.add(dto);
            } else {
                DepartmentDto parent = dtoMap.get(d.getParentId());
                if (parent != null) {
                    parent.getChildren().add(dto);
                } else {
                    roots.add(dto); // orphan node — treat as root
                }
            }
        }
        return roots;
    }

    private DepartmentDto toDto(Department d) {
        DepartmentDto dto = new DepartmentDto();
        dto.setId(d.getId());
        dto.setName(d.getName());
        dto.setCode(d.getCode());
        dto.setDescription(d.getDescription());
        dto.setSortOrder(d.getSortOrder());
        dto.setParentId(d.getParentId());
        return dto;
    }

    public Department create(Map<String, String> body) {
        String name = body.get("name");
        if (name == null || name.isBlank()) throw new IllegalArgumentException("部门名称不能为空");
        if (deptRepository.existsByName(name.trim())) throw new IllegalArgumentException("部门名称已存在");
        Department d = new Department();
        d.setName(name.trim());
        d.setCode(nullIfBlank(body.get("code")));
        d.setDescription(nullIfBlank(body.get("description")));
        String sortStr = body.get("sortOrder");
        d.setSortOrder(sortStr != null && !sortStr.isBlank() ? Integer.parseInt(sortStr) : 0);
        String parentIdStr = body.get("parentId");
        d.setParentId(parentIdStr != null && !parentIdStr.isBlank() ? Long.parseLong(parentIdStr) : null);
        return deptRepository.save(d);
    }

    public Department update(Long id, Map<String, String> body) {
        Department d = deptRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("部门不存在"));
        String name = body.get("name");
        if (name == null || name.isBlank()) throw new IllegalArgumentException("部门名称不能为空");
        if (deptRepository.existsByNameAndIdNot(name.trim(), id)) throw new IllegalArgumentException("部门名称已存在");
        d.setName(name.trim());
        d.setCode(nullIfBlank(body.get("code")));
        d.setDescription(nullIfBlank(body.get("description")));
        String sortStr = body.get("sortOrder");
        if (sortStr != null && !sortStr.isBlank()) d.setSortOrder(Integer.parseInt(sortStr));
        String parentIdStr = body.get("parentId");
        d.setParentId(parentIdStr != null && !parentIdStr.isBlank() ? Long.parseLong(parentIdStr) : null);
        return deptRepository.save(d);
    }

    public void delete(Long id) {
        if (!deptRepository.existsById(id)) throw new IllegalArgumentException("部门不存在");
        deptRepository.deleteById(id);
    }

    /** 导出Excel（按筛选条件）*/
    public byte[] exportExcel(String search) throws IOException {
        List<Department> list = getFiltered(search);
        return buildExcel(list);
    }

    /** 导出全部Excel */
    public byte[] exportAll() throws IOException {
        return buildExcel(getAll());
    }

    /** 下载导入模板 */
    public byte[] getTemplate() throws IOException {
        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            Sheet sheet = wb.createSheet("部门导入模板");
            CellStyle header = headerStyle(wb);
            String[] cols = {"部门名称*", "部门编码", "描述", "排序号"};
            Row hRow = sheet.createRow(0);
            for (int i = 0; i < cols.length; i++) {
                Cell c = hRow.createCell(i);
                c.setCellValue(cols[i]);
                c.setCellStyle(header);
                sheet.setColumnWidth(i, 5000);
            }
            // Sample row
            Row r = sheet.createRow(1);
            r.createCell(0).setCellValue("研发部");
            r.createCell(1).setCellValue("R&D");
            r.createCell(2).setCellValue("负责产品研发");
            r.createCell(3).setCellValue("1");
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            wb.write(out);
            return out.toByteArray();
        }
    }

    /** 导入Excel */
    public Map<String, Object> importExcel(MultipartFile file) throws IOException {
        int success = 0, failed = 0;
        List<String> errors = new ArrayList<>();
        try (Workbook wb = WorkbookFactory.create(file.getInputStream())) {
            Sheet sheet = wb.getSheetAt(0);
            for (int i = 1; i <= sheet.getLastRowNum(); i++) {
                Row row = sheet.getRow(i);
                if (row == null) continue;
                try {
                    String name = cellStr(row.getCell(0));
                    if (name.isBlank()) { errors.add("第" + (i+1) + "行: 部门名称为空"); failed++; continue; }
                    String code = cellStr(row.getCell(1));
                    String desc = cellStr(row.getCell(2));
                    String sortStr = cellStr(row.getCell(3));
                    int sortOrder = sortStr.isBlank() ? 0 : (int) Double.parseDouble(sortStr);
                    if (deptRepository.existsByName(name)) {
                        errors.add("第" + (i+1) + "行: 部门\"" + name + "\"已存在，跳过");
                        failed++; continue;
                    }
                    Department d = new Department();
                    d.setName(name);
                    d.setCode(code.isBlank() ? null : code);
                    d.setDescription(desc.isBlank() ? null : desc);
                    d.setSortOrder(sortOrder);
                    deptRepository.save(d);
                    success++;
                } catch (Exception e) {
                    errors.add("第" + (i+1) + "行: " + e.getMessage());
                    failed++;
                }
            }
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("success", success);
        result.put("failed", failed);
        result.put("errors", errors);
        return result;
    }

    private byte[] buildExcel(List<Department> list) throws IOException {
        try (XSSFWorkbook wb = new XSSFWorkbook()) {
            Sheet sheet = wb.createSheet("部门列表");
            CellStyle hs = headerStyle(wb);
            String[] cols = {"ID", "部门名称", "部门编码", "描述", "排序号", "创建时间"};
            Row hRow = sheet.createRow(0);
            for (int i = 0; i < cols.length; i++) {
                Cell c = hRow.createCell(i);
                c.setCellValue(cols[i]);
                c.setCellStyle(hs);
            }
            sheet.setColumnWidth(0, 2000);
            sheet.setColumnWidth(1, 5000);
            sheet.setColumnWidth(2, 3500);
            sheet.setColumnWidth(3, 8000);
            sheet.setColumnWidth(4, 2500);
            sheet.setColumnWidth(5, 5000);
            DateTimeFormatter fmt = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");
            for (int i = 0; i < list.size(); i++) {
                Department d = list.get(i);
                Row row = sheet.createRow(i + 1);
                row.createCell(0).setCellValue(d.getId());
                row.createCell(1).setCellValue(orEmpty(d.getName()));
                row.createCell(2).setCellValue(orEmpty(d.getCode()));
                row.createCell(3).setCellValue(orEmpty(d.getDescription()));
                row.createCell(4).setCellValue(d.getSortOrder() != null ? d.getSortOrder() : 0);
                row.createCell(5).setCellValue(d.getCreatedAt() != null ? d.getCreatedAt().format(fmt) : "");
            }
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            wb.write(out);
            return out.toByteArray();
        }
    }

    private CellStyle headerStyle(Workbook wb) {
        CellStyle s = wb.createCellStyle();
        Font f = wb.createFont();
        f.setBold(true);
        s.setFont(f);
        s.setFillForegroundColor(IndexedColors.LIGHT_BLUE.getIndex());
        s.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        return s;
    }

    private String cellStr(Cell cell) {
        if (cell == null) return "";
        return switch (cell.getCellType()) {
            case STRING -> cell.getStringCellValue().trim();
            case NUMERIC -> {
                double v = cell.getNumericCellValue();
                yield v == Math.floor(v) ? String.valueOf((long) v) : String.valueOf(v);
            }
            default -> "";
        };
    }

    private String nullIfBlank(String s) { return (s == null || s.isBlank()) ? null : s.trim(); }
    private String orEmpty(String s) { return s != null ? s : ""; }
}

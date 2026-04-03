package com.metrology.controller;

import com.metrology.dto.DepartmentDto;
import com.metrology.entity.Department;
import com.metrology.service.DepartmentService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/departments")
@RequiredArgsConstructor
public class DepartmentController {

    private final DepartmentService deptService;

    /** 获取部门列表（支持搜索筛选） */
    @GetMapping
    public ResponseEntity<List<Department>> list(@RequestParam(required = false) String search) {
        return ResponseEntity.ok(deptService.getFiltered(search));
    }

    /** 获取部门树结构 */
    @GetMapping("/tree")
    public ResponseEntity<List<DepartmentDto>> tree() {
        return ResponseEntity.ok(deptService.getTree());
    }

    /** 新增部门 */
    @PostMapping
    public ResponseEntity<?> create(@RequestBody Map<String, String> body) {
        try {
            return ResponseEntity.ok(deptService.create(body));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    /** 修改部门 */
    @PutMapping("/{id}")
    public ResponseEntity<?> update(@PathVariable Long id, @RequestBody Map<String, String> body) {
        try {
            return ResponseEntity.ok(deptService.update(id, body));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    /** 删除部门 */
    @DeleteMapping("/{id}")
    public ResponseEntity<?> delete(@PathVariable Long id) {
        try {
            deptService.delete(id);
            return ResponseEntity.ok().build();
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    /** 导出当前筛选结果 */
    @GetMapping("/export")
    public ResponseEntity<byte[]> export(@RequestParam(required = false) String search) throws IOException {
        byte[] data = deptService.exportExcel(search);
        String filename = URLEncoder.encode("部门列表.xlsx", StandardCharsets.UTF_8);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename*=UTF-8''" + filename)
                .contentType(MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(data);
    }

    /** 导出全部 */
    @GetMapping("/export/all")
    public ResponseEntity<byte[]> exportAll() throws IOException {
        byte[] data = deptService.exportAll();
        String filename = URLEncoder.encode("部门列表(全部).xlsx", StandardCharsets.UTF_8);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename*=UTF-8''" + filename)
                .contentType(MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(data);
    }

    /** 下载导入模板 */
    @GetMapping("/template")
    public ResponseEntity<byte[]> template() throws IOException {
        byte[] data = deptService.getTemplate();
        String filename = URLEncoder.encode("部门导入模板.xlsx", StandardCharsets.UTF_8);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename*=UTF-8''" + filename)
                .contentType(MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(data);
    }

    /** 导入Excel */
    @PostMapping("/import")
    public ResponseEntity<?> importExcel(@RequestParam("file") MultipartFile file) throws IOException {
        return ResponseEntity.ok(deptService.importExcel(file));
    }
}

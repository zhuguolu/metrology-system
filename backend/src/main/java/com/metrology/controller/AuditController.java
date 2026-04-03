package com.metrology.controller;

import com.metrology.entity.AuditRecord;
import com.metrology.entity.User;
import com.metrology.repository.UserRepository;
import com.metrology.service.AuditService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/audit")
@RequiredArgsConstructor
public class AuditController {

    private final AuditService auditService;
    private final UserRepository userRepository;

    private boolean isAdmin(String username) {
        return userRepository.findByUsername(username)
                .map(u -> "ADMIN".equals(u.getRole())).orElse(false);
    }

    /** 待审批列表（管理员） */
    @GetMapping("/pending")
    public ResponseEntity<?> pending(@AuthenticationPrincipal UserDetails user) {
        if (!isAdmin(user.getUsername())) return ResponseEntity.status(403).body(Map.of("message", "无权限"));
        return ResponseEntity.ok(auditService.getPending());
    }

    /** 待审批数量 */
    @GetMapping("/pending/count")
    public ResponseEntity<?> pendingCount(@AuthenticationPrincipal UserDetails user) {
        if (!isAdmin(user.getUsername())) return ResponseEntity.ok(Map.of("count", 0));
        return ResponseEntity.ok(Map.of("count", auditService.getPendingCount()));
    }

    /** 我的申请记录 */
    @GetMapping("/my")
    public ResponseEntity<?> my(@AuthenticationPrincipal UserDetails user) {
        return ResponseEntity.ok(auditService.getMyRecords(user.getUsername()));
    }

    /** 全部记录（管理员，分页） */
    @GetMapping
    public ResponseEntity<?> all(@AuthenticationPrincipal UserDetails user,
                                  @RequestParam(defaultValue = "1") int page,
                                  @RequestParam(defaultValue = "20") int size) {
        if (!isAdmin(user.getUsername())) return ResponseEntity.status(403).body(Map.of("message", "无权限"));
        return ResponseEntity.ok(auditService.getAll(
                PageRequest.of(Math.max(page - 1, 0), size, Sort.by(Sort.Direction.DESC, "submittedAt"))));
    }

    /** 单条记录详情 */
    @GetMapping("/{id}")
    public ResponseEntity<?> getById(@AuthenticationPrincipal UserDetails user, @PathVariable Long id) {
        try {
            AuditRecord record = auditService.getById(id);
            // 只有本人或管理员可查看
            if (!record.getSubmittedBy().equals(user.getUsername()) && !isAdmin(user.getUsername())) {
                return ResponseEntity.status(403).body(Map.of("message", "无权限"));
            }
            return ResponseEntity.ok(record);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    /** 审批通过 */
    @PostMapping("/{id}/approve")
    public ResponseEntity<?> approve(@AuthenticationPrincipal UserDetails user,
                                      @PathVariable Long id,
                                      @RequestBody(required = false) Map<String, String> body) {
        if (!isAdmin(user.getUsername())) return ResponseEntity.status(403).body(Map.of("message", "无权限"));
        try {
            String remark = body != null ? body.get("remark") : null;
            return ResponseEntity.ok(auditService.approve(user.getUsername(), id, remark));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    /** 驳回 */
    @PostMapping("/{id}/reject")
    public ResponseEntity<?> reject(@AuthenticationPrincipal UserDetails user,
                                     @PathVariable Long id,
                                     @RequestBody(required = false) Map<String, String> body) {
        if (!isAdmin(user.getUsername())) return ResponseEntity.status(403).body(Map.of("message", "无权限"));
        try {
            String reason = body != null ? body.get("reason") : null;
            return ResponseEntity.ok(auditService.reject(user.getUsername(), id, reason));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    /** 获取审批流程配置 */
    @GetMapping("/workflow")
    public ResponseEntity<?> getWorkflow(@AuthenticationPrincipal UserDetails user,
                                          @RequestParam(defaultValue = "DEVICE") String module) {
        if (!isAdmin(user.getUsername())) return ResponseEntity.status(403).body(Map.of("message", "无权限"));
        return ResponseEntity.ok(auditService.getWorkflow(module));
    }

    /** 保存审批流程配置 */
    @PutMapping("/workflow")
    public ResponseEntity<?> saveWorkflow(@AuthenticationPrincipal UserDetails user,
                                           @RequestParam(defaultValue = "DEVICE") String module,
                                           @RequestBody List<Map<String, Object>> steps) {
        if (!isAdmin(user.getUsername())) return ResponseEntity.status(403).body(Map.of("message", "无权限"));
        try {
            return ResponseEntity.ok(auditService.saveWorkflow(module, steps));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }
}

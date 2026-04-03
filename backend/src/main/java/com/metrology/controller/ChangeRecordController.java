package com.metrology.controller;

import com.metrology.entity.AuditRecord;
import com.metrology.repository.UserRepository;
import com.metrology.service.AuditService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.Map;

@RestController
@RequestMapping("/api/change-records")
@RequiredArgsConstructor
public class ChangeRecordController {

    private final AuditService auditService;
    private final UserRepository userRepository;

    private boolean isAdmin(String username) {
        return userRepository.findByUsername(username)
                .map(u -> "ADMIN".equals(u.getRole())).orElse(false);
    }

    @GetMapping
    public ResponseEntity<?> list(@AuthenticationPrincipal UserDetails user,
                                  @RequestParam(defaultValue = "1") int page,
                                  @RequestParam(defaultValue = "20") int size,
                                  @RequestParam(required = false) String keyword,
                                  @RequestParam(required = false) String type,
                                  @RequestParam(required = false) String status,
                                  @RequestParam(required = false) String submittedBy,
                                  @RequestParam(required = false) String dateFrom,
                                  @RequestParam(required = false) String dateTo) {
        try {
            return ResponseEntity.ok(auditService.getChangeRecords(
                    user.getUsername(),
                    isAdmin(user.getUsername()),
                    keyword,
                    type,
                    status,
                    submittedBy,
                    parseDate(dateFrom),
                    parseDate(dateTo),
                    page,
                    size
            ));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @GetMapping("/{id}")
    public ResponseEntity<?> getById(@AuthenticationPrincipal UserDetails user, @PathVariable Long id) {
        try {
            AuditRecord record = auditService.getById(id);
            if (!"APPROVED".equals(record.getStatus())) {
                return ResponseEntity.status(404).body(Map.of("message", "记录不存在"));
            }
            if (!record.getSubmittedBy().equals(user.getUsername()) && !isAdmin(user.getUsername())) {
                return ResponseEntity.status(403).body(Map.of("message", "无权限"));
            }
            return ResponseEntity.ok(record);
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    private LocalDate parseDate(String value) {
        if (value == null || value.isBlank()) return null;
        try {
            return LocalDate.parse(value);
        } catch (DateTimeParseException e) {
            throw new IllegalArgumentException("日期格式错误，请使用 YYYY-MM-DD");
        }
    }
}

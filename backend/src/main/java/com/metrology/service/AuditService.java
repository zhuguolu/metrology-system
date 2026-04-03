package com.metrology.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.metrology.dto.ChangeRecordItemDto;
import com.metrology.dto.ChangeRecordPageDto;
import com.metrology.dto.ChangeRecordStatsDto;
import com.metrology.dto.DeviceDto;
import com.metrology.entity.AuditRecord;
import com.metrology.entity.AuditWorkflowStep;
import com.metrology.entity.UserSettings;
import com.metrology.repository.AuditRecordRepository;
import com.metrology.repository.AuditWorkflowStepRepository;
import com.metrology.repository.DeviceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.Comparator;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AuditService {

    private final AuditRecordRepository auditRepository;
    private final AuditWorkflowStepRepository workflowRepository;
    private final DeviceRepository deviceRepository;
    private final DeviceService deviceService;
    private final ObjectMapper objectMapper;

    /** 普通用户提交新增申请 */
    public AuditRecord submitCreate(String username, DeviceDto dto) {
        AuditRecord record = new AuditRecord();
        record.setType("CREATE");
        record.setEntityType("DEVICE");
        record.setSubmittedBy(username);
        try { record.setNewData(objectMapper.writeValueAsString(dto)); } catch (Exception ignored) {}
        if (dto.getRemark() != null) record.setRemark(dto.getRemark());
        return auditRepository.save(record);
    }

    /** 普通用户提交修改申请 */
    public AuditRecord submitUpdate(String username, Long id, DeviceDto dto) {
        AuditRecord record = new AuditRecord();
        record.setType("UPDATE");
        record.setEntityType("DEVICE");
        record.setEntityId(id);
        record.setSubmittedBy(username);
        // 序列化原始快照
        deviceRepository.findById(id).ifPresent(device -> {
            try {
                UserSettings settings = deviceService.getSettings(username);
                DeviceDto original = deviceService.toDto(device, settings, false);
                record.setOriginalData(objectMapper.writeValueAsString(original));
            } catch (Exception ignored) {}
        });
        try { record.setNewData(objectMapper.writeValueAsString(dto)); } catch (Exception ignored) {}
        return auditRepository.save(record);
    }

    /** 普通用户提交删除申请 */
    public AuditRecord submitDelete(String username, Long id) {
        AuditRecord record = new AuditRecord();
        record.setType("DELETE");
        record.setEntityType("DEVICE");
        record.setEntityId(id);
        record.setSubmittedBy(username);
        deviceRepository.findById(id).ifPresent(device -> {
            try {
                UserSettings settings = deviceService.getSettings(username);
                DeviceDto original = deviceService.toDto(device, settings, false);
                record.setOriginalData(objectMapper.writeValueAsString(original));
            } catch (Exception ignored) {}
        });
        return auditRepository.save(record);
    }

    /** 管理员直接新增，也保留一条已生效的变更记录 */
    public AuditRecord recordDirectCreate(String adminUsername, DeviceDto created) {
        AuditRecord record = new AuditRecord();
        record.setType("CREATE");
        record.setEntityType("DEVICE");
        record.setEntityId(created.getId());
        record.setSubmittedBy(adminUsername);
        record.setStatus("APPROVED");
        record.setApprovedBy(adminUsername);
        record.setApprovedAt(LocalDateTime.now());
        try { record.setNewData(objectMapper.writeValueAsString(created)); } catch (Exception ignored) {}
        if (created.getRemark() != null) record.setRemark(created.getRemark());
        return auditRepository.save(record);
    }

    /** 管理员直接修改，也保留一条已生效的变更记录 */
    public AuditRecord recordDirectUpdate(String adminUsername, Long id, DeviceDto changes) {
        AuditRecord record = new AuditRecord();
        record.setType("UPDATE");
        record.setEntityType("DEVICE");
        record.setEntityId(id);
        record.setSubmittedBy(adminUsername);
        record.setStatus("APPROVED");
        record.setApprovedBy(adminUsername);
        record.setApprovedAt(LocalDateTime.now());
        var device = deviceRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("设备不存在"));
        try {
            UserSettings settings = deviceService.getSettings(adminUsername);
            DeviceDto original = deviceService.toDto(device, settings, true);
            record.setOriginalData(objectMapper.writeValueAsString(original));
        } catch (Exception ignored) {}
        try { record.setNewData(objectMapper.writeValueAsString(changes)); } catch (Exception ignored) {}
        if (changes.getRemark() != null) record.setRemark(changes.getRemark());
        return auditRepository.save(record);
    }

    /** 管理员直接删除，也保留一条已生效的变更记录 */
    public AuditRecord recordDirectDelete(String adminUsername, Long id) {
        AuditRecord record = new AuditRecord();
        record.setType("DELETE");
        record.setEntityType("DEVICE");
        record.setEntityId(id);
        record.setSubmittedBy(adminUsername);
        record.setStatus("APPROVED");
        record.setApprovedBy(adminUsername);
        record.setApprovedAt(LocalDateTime.now());
        var device = deviceRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("设备不存在"));
        try {
            UserSettings settings = deviceService.getSettings(adminUsername);
            DeviceDto original = deviceService.toDto(device, settings, true);
            record.setOriginalData(objectMapper.writeValueAsString(original));
            if (original.getRemark() != null) record.setRemark(original.getRemark());
        } catch (Exception ignored) {}
        return auditRepository.save(record);
    }

    /** 管理员审批通过 */
    @Transactional
    public AuditRecord approve(String adminUsername, Long auditId, String remark) {
        AuditRecord record = auditRepository.findById(auditId)
                .orElseThrow(() -> new IllegalArgumentException("审核记录不存在"));
        if (!"PENDING".equals(record.getStatus())) {
            throw new IllegalStateException("该记录已被处理");
        }
        // 执行实际操作
        try {
            if ("DEVICE".equals(record.getEntityType())) {
                switch (record.getType()) {
                    case "CREATE" -> {
                        DeviceDto dto = objectMapper.readValue(record.getNewData(), DeviceDto.class);
                        DeviceDto created = deviceService.createDevice(adminUsername, dto);
                        record.setEntityId(created.getId());
                    }
                    case "UPDATE" -> {
                        DeviceDto dto = objectMapper.readValue(record.getNewData(), DeviceDto.class);
                        deviceService.updateDevice(adminUsername, record.getEntityId(), dto);
                    }
                    case "DELETE" -> deviceService.deleteDevice(record.getEntityId());
                }
            }
        } catch (Exception e) {
            throw new RuntimeException("执行操作失败: " + e.getMessage(), e);
        }
        record.setStatus("APPROVED");
        record.setApprovedBy(adminUsername);
        record.setApprovedAt(LocalDateTime.now());
        if (remark != null && !remark.isBlank()) record.setRemark(remark);
        return auditRepository.save(record);
    }

    /** 管理员驳回 */
    public AuditRecord reject(String adminUsername, Long auditId, String reason) {
        AuditRecord record = auditRepository.findById(auditId)
                .orElseThrow(() -> new IllegalArgumentException("审核记录不存在"));
        if (!"PENDING".equals(record.getStatus())) {
            throw new IllegalStateException("该记录已被处理");
        }
        record.setStatus("REJECTED");
        record.setApprovedBy(adminUsername);
        record.setApprovedAt(LocalDateTime.now());
        record.setRejectReason(reason);
        return auditRepository.save(record);
    }

    public List<AuditRecord> getPending() {
        return auditRepository.findByStatusOrderBySubmittedAtDesc("PENDING");
    }

    public List<AuditRecord> getMyRecords(String username) {
        return auditRepository.findBySubmittedByOrderBySubmittedAtDesc(username);
    }

    public Page<AuditRecord> getAll(Pageable pageable) {
        return auditRepository.findAllByOrderBySubmittedAtDesc(pageable);
    }

    public AuditRecord getById(Long id) {
        return auditRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("审核记录不存在"));
    }

    public long getPendingCount() {
        return auditRepository.countByStatus("PENDING");
    }

    public ChangeRecordPageDto getChangeRecords(String username,
                                                boolean admin,
                                                String keyword,
                                                String type,
                                                String status,
                                                String submittedBy,
                                                LocalDate dateFrom,
                                                LocalDate dateTo,
                                                int page,
                                                int size) {
        List<AuditRecord> accessibleRecords = admin
                ? auditRepository.findAll(Sort.by(Sort.Direction.DESC, "approvedAt"))
                : auditRepository.findBySubmittedByOrderBySubmittedAtDesc(username);

        String normalizedKeyword = keyword == null ? "" : keyword.trim().toLowerCase();
        String normalizedType = normalizeFilter(type);
        String normalizedSubmitter = normalizeFilter(submittedBy);

        List<AuditRecord> filteredRecords = accessibleRecords.stream()
                .filter(this::isEffectiveChangeRecord)
                .filter(record -> matchesType(record, normalizedType))
                .filter(record -> matchesSubmitter(record, admin, normalizedSubmitter))
                .filter(record -> matchesDateRange(record, dateFrom, dateTo))
                .filter(record -> matchesKeyword(record, normalizedKeyword, admin))
                .sorted(Comparator.comparing(AuditRecord::getApprovedAt,
                        Comparator.nullsLast(Comparator.reverseOrder())))
                .collect(Collectors.toList());

        ChangeRecordStatsDto stats = buildStats(filteredRecords);
        List<ChangeRecordItemDto> mappedItems = filteredRecords.stream()
                .map(this::toChangeRecordItem)
                .collect(Collectors.toList());

        int safePage = Math.max(page, 1);
        int safeSize = Math.max(size, 1);
        int fromIndex = Math.min((safePage - 1) * safeSize, mappedItems.size());
        int toIndex = Math.min(fromIndex + safeSize, mappedItems.size());

        ChangeRecordPageDto result = new ChangeRecordPageDto();
        result.setItems(mappedItems.subList(fromIndex, toIndex));
        result.setTotal(mappedItems.size());
        result.setPage(safePage);
        result.setSize(safeSize);
        result.setStats(stats);
        return result;
    }

    // ── 审批流程配置 ──────────────────────────────

    public List<AuditWorkflowStep> getWorkflow(String moduleName) {
        return workflowRepository.findByModuleNameOrderByStepOrderAsc(moduleName);
    }

    @Transactional
    public List<AuditWorkflowStep> saveWorkflow(String moduleName, List<Map<String, Object>> steps) {
        workflowRepository.deleteByModuleName(moduleName);
        for (int i = 0; i < steps.size(); i++) {
            Map<String, Object> s = steps.get(i);
            AuditWorkflowStep step = new AuditWorkflowStep();
            step.setModuleName(moduleName);
            step.setStepOrder(i + 1);
            step.setStepName((String) s.get("stepName"));
            step.setApproverType((String) s.getOrDefault("approverType", "ROLE"));
            step.setApproverValue((String) s.getOrDefault("approverValue", "ADMIN"));
            workflowRepository.save(step);
        }
        return workflowRepository.findByModuleNameOrderByStepOrderAsc(moduleName);
    }

    private String normalizeFilter(String value) {
        if (value == null) return null;
        String normalized = value.trim();
        return normalized.isEmpty() ? null : normalized;
    }

    private boolean matchesType(AuditRecord record, String type) {
        return type == null || Objects.equals(record.getType(), type);
    }

    private boolean isEffectiveChangeRecord(AuditRecord record) {
        return Objects.equals(record.getStatus(), "APPROVED");
    }

    private boolean matchesSubmitter(AuditRecord record, boolean admin, String submittedBy) {
        if (!admin || submittedBy == null) return true;
        return submittedBy.equalsIgnoreCase(record.getSubmittedBy());
    }

    private boolean matchesDateRange(AuditRecord record, LocalDate dateFrom, LocalDate dateTo) {
        if (record.getApprovedAt() == null) return dateFrom == null && dateTo == null;
        LocalDate effectiveDate = record.getApprovedAt().toLocalDate();
        if (dateFrom != null && effectiveDate.isBefore(dateFrom)) return false;
        return dateTo == null || !effectiveDate.isAfter(dateTo);
    }

    private boolean matchesKeyword(AuditRecord record, String keyword, boolean admin) {
        if (keyword == null || keyword.isEmpty()) return true;
        List<String> fields = new ArrayList<>();
        fields.add(extractField(record.getNewData(), "name"));
        fields.add(extractField(record.getOriginalData(), "name"));
        fields.add(extractField(record.getNewData(), "metricNo"));
        fields.add(extractField(record.getOriginalData(), "metricNo"));
        fields.add(record.getRemark());
        fields.add(record.getRejectReason());
        if (admin) {
            fields.add(record.getSubmittedBy());
            fields.add(record.getApprovedBy());
        }
        return fields.stream()
                .filter(Objects::nonNull)
                .map(value -> value.toLowerCase())
                .anyMatch(value -> value.contains(keyword));
    }

    private ChangeRecordStatsDto buildStats(List<AuditRecord> records) {
        ChangeRecordStatsDto stats = new ChangeRecordStatsDto();
        stats.setTotal(records.size());
        stats.setPending(0);
        stats.setApproved(records.size());
        stats.setRejected(0);
        stats.setCreateCount(records.stream().filter(record -> "CREATE".equals(record.getType())).count());
        stats.setUpdateCount(records.stream().filter(record -> "UPDATE".equals(record.getType())).count());
        stats.setDeleteCount(records.stream().filter(record -> "DELETE".equals(record.getType())).count());
        Set<String> submitters = records.stream()
                .map(AuditRecord::getSubmittedBy)
                .filter(Objects::nonNull)
                .collect(Collectors.toCollection(LinkedHashSet::new));
        stats.setSubmitterCount(submitters.size());
        return stats;
    }

    private ChangeRecordItemDto toChangeRecordItem(AuditRecord record) {
        ChangeRecordItemDto dto = new ChangeRecordItemDto();
        dto.setId(record.getId());
        dto.setType(record.getType());
        dto.setStatus(record.getStatus());
        dto.setEntityType(record.getEntityType());
        dto.setEntityId(record.getEntityId());
        dto.setSubmittedBy(record.getSubmittedBy());
        dto.setSubmittedAt(record.getSubmittedAt());
        dto.setApprovedBy(record.getApprovedBy());
        dto.setApprovedAt(record.getApprovedAt());
        dto.setRemark(record.getRemark());
        dto.setRejectReason(record.getRejectReason());
        dto.setDeviceName(firstNonBlank(
                extractField(record.getNewData(), "name"),
                extractField(record.getOriginalData(), "name")
        ));
        dto.setMetricNo(firstNonBlank(
                extractField(record.getNewData(), "metricNo"),
                extractField(record.getOriginalData(), "metricNo")
        ));
        dto.setChangedFieldCount(countChangedFields(record));
        return dto;
    }

    private Integer countChangedFields(AuditRecord record) {
        Map<String, Object> original = parseMap(record.getOriginalData());
        Map<String, Object> current = parseMap(record.getNewData());
        Set<String> skipFields = Set.of("id", "nextCalDate", "nextDate", "validity", "daysPassed");

        if ("UPDATE".equals(record.getType())) {
            return (int) current.entrySet().stream()
                    .filter(entry -> !skipFields.contains(entry.getKey()))
                    .filter(entry -> entry.getValue() != null)
                    .filter(entry -> !Objects.equals(
                            normalizeComparableValue(original.get(entry.getKey())),
                            normalizeComparableValue(entry.getValue())))
                    .count();
        }
        if ("CREATE".equals(record.getType())) {
            return (int) current.entrySet().stream()
                    .filter(entry -> !skipFields.contains(entry.getKey()))
                    .filter(entry -> hasDisplayValue(entry.getValue()))
                    .count();
        }
        return (int) original.entrySet().stream()
                .filter(entry -> !skipFields.contains(entry.getKey()))
                .filter(entry -> hasDisplayValue(entry.getValue()))
                .count();
    }

    private String extractField(String json, String fieldName) {
        return stringify(parseMap(json).get(fieldName));
    }

    private Map<String, Object> parseMap(String json) {
        if (json == null || json.isBlank()) return Collections.emptyMap();
        try {
            return objectMapper.readValue(json, Map.class);
        } catch (Exception ignored) {
            return Collections.emptyMap();
        }
    }

    private boolean hasDisplayValue(Object value) {
        String stringified = stringify(value);
        return stringified != null && !stringified.isBlank();
    }

    private String normalizeComparableValue(Object value) {
        String stringified = stringify(value);
        return stringified == null || stringified.isBlank() ? null : stringified;
    }

    private String stringify(Object value) {
        return value == null ? null : String.valueOf(value).trim();
    }

    private String firstNonBlank(String... values) {
        for (String value : values) {
            if (value != null && !value.isBlank()) return value;
        }
        return null;
    }
}

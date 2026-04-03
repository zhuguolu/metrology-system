package com.metrology.controller;

import com.metrology.dto.LoginResponse;
import com.metrology.dto.RegisterRequest;
import com.metrology.entity.User;
import com.metrology.entity.UserPermission;
import com.metrology.repository.UserPermissionRepository;
import com.metrology.repository.UserRepository;
import com.metrology.service.AuthService;
import com.metrology.service.PermissionService;
import com.metrology.service.UserFileGrantService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserManagementController {

    private final UserRepository userRepository;
    private final UserPermissionRepository permissionRepository;
    private final PermissionService permissionService;
    private final AuthService authService;
    private final UserFileGrantService userFileGrantService;

    private static final String DEPT_SEPARATOR = ",";

    @PostMapping
    public ResponseEntity<?> createUser(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody Map<String, Object> body) {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.USER_MANAGE)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足"));
        }
        try {
            RegisterRequest req = new RegisterRequest();
            req.setUsername((String) body.get("username"));
            req.setPassword((String) body.get("password"));
            LoginResponse res = authService.register(req);

            String role = (String) body.get("role");
            List<String> departments = parseDepartments(body);
            @SuppressWarnings("unchecked")
            List<String> permissions = (List<String>) body.get("permissions");
            List<Long> readonlyFolderIds = parseFolderIds(body.get("readonlyFolderIds"));

            User newUser = userRepository.findByUsername(res.getUsername()).orElseThrow();
            if (role != null && !role.isEmpty()) {
                newUser.setRole(role);
            }
            if (body.containsKey("department") || body.containsKey("departments")) {
                newUser.setDepartment(joinDepartments(departments));
            }
            userRepository.save(newUser);

            if (permissions != null && !"ADMIN".equals(role)) {
                for (String p : permissions) {
                    permissionRepository.save(new UserPermission(null, newUser.getId(), p));
                }
            }
            userFileGrantService.replaceReadonlyFolders(userDetails.getUsername(), newUser.getId(), readonlyFolderIds);

            return ResponseEntity.ok(Map.of("message", "用户创建成功", "username", res.getUsername()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @GetMapping
    public ResponseEntity<?> listUsers(@AuthenticationPrincipal UserDetails userDetails) {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.USER_MANAGE)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足"));
        }
        List<Map<String, Object>> result = userRepository.findAll().stream().map(user -> {
            List<String> perms = permissionRepository.findByUserId(user.getId())
                    .stream()
                    .map(UserPermission::getPermission)
                    .collect(Collectors.toList());

            Map<String, Object> item = new LinkedHashMap<>();
            item.put("id", user.getId());
            item.put("username", user.getUsername());
            item.put("role", user.getRole() != null ? user.getRole() : "USER");
            item.put("department", user.getDepartment() != null ? user.getDepartment() : "");
            item.put("departments", splitDepartments(user.getDepartment()));
            item.put("permissions", perms);
            item.put("readonlyFolders", userFileGrantService.getReadonlyFolders(user.getId()));
            item.put("readonlyFolderIds", userFileGrantService.getReadonlyFolderIds(user.getId()));
            item.put("createdAt", user.getCreatedAt() != null ? user.getCreatedAt().toString() : "");
            return item;
        }).collect(Collectors.toList());
        return ResponseEntity.ok(result);
    }

    @PutMapping("/{id}/role-permissions")
    public ResponseEntity<?> updateRolePermissions(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable Long id,
            @RequestBody Map<String, Object> body) {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.USER_MANAGE)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足"));
        }

        User user = userRepository.findById(id).orElseThrow();
        String role = (String) body.get("role");
        List<String> departments = parseDepartments(body);
        @SuppressWarnings("unchecked")
        List<String> permissions = (List<String>) body.get("permissions");
        List<Long> readonlyFolderIds = parseFolderIds(body.get("readonlyFolderIds"));

        if (role != null) {
            user.setRole(role);
        }
        if (body.containsKey("department") || body.containsKey("departments")) {
            user.setDepartment(joinDepartments(departments));
        }
        userRepository.save(user);

        if (permissions != null) {
            permissionRepository.deleteByUserId(id);
            for (String permission : permissions) {
                permissionRepository.save(new UserPermission(null, id, permission));
            }
        }

        userFileGrantService.replaceReadonlyFolders(userDetails.getUsername(), id, readonlyFolderIds);
        return ResponseEntity.ok(Map.of("message", "更新成功"));
    }

    @PutMapping("/{id}/password")
    public ResponseEntity<?> resetUserPassword(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable Long id,
            @RequestBody Map<String, Object> body) {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.USER_MANAGE)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足"));
        }
        try {
            String newPassword = body.get("password") == null ? null : String.valueOf(body.get("password"));
            authService.resetPasswordByAdmin(id, newPassword);
            return ResponseEntity.ok(Map.of("message", "密码修改成功"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteUser(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable Long id) {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.USER_MANAGE)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足"));
        }
        User current = userRepository.findByUsername(userDetails.getUsername()).orElseThrow();
        if (current.getId().equals(id)) {
            return ResponseEntity.badRequest().body(Map.of("message", "不能删除当前登录账号"));
        }
        permissionRepository.deleteByUserId(id);
        userFileGrantService.replaceReadonlyFolders(userDetails.getUsername(), id, Collections.emptyList());
        userRepository.deleteById(id);
        return ResponseEntity.ok().build();
    }

    private List<Long> parseFolderIds(Object raw) {
        if (!(raw instanceof List<?> rawList)) {
            return Collections.emptyList();
        }
        return rawList.stream()
                .filter(Objects::nonNull)
                .map(String::valueOf)
                .map(String::trim)
                .filter(value -> !value.isBlank())
                .map(Long::valueOf)
                .distinct()
                .collect(Collectors.toList());
    }

    private List<String> parseDepartments(Map<String, Object> body) {
        if (body == null) return Collections.emptyList();
        Object departmentsObj = body.get("departments");
        if (departmentsObj instanceof List<?> departmentsList) {
            return departmentsList.stream()
                    .filter(Objects::nonNull)
                    .map(String::valueOf)
                    .map(String::trim)
                    .filter(s -> !s.isBlank())
                    .distinct()
                    .collect(Collectors.toList());
        }
        Object departmentObj = body.get("department");
        if (departmentObj == null) return Collections.emptyList();
        return splitDepartments(String.valueOf(departmentObj));
    }

    private List<String> splitDepartments(String stored) {
        if (stored == null || stored.isBlank()) return Collections.emptyList();
        return Arrays.stream(stored.replace('，', ',').split(DEPT_SEPARATOR))
                .map(String::trim)
                .filter(s -> !s.isBlank())
                .distinct()
                .collect(Collectors.toList());
    }

    private String joinDepartments(List<String> departments) {
        if (departments == null || departments.isEmpty()) return null;
        return departments.stream()
                .map(String::trim)
                .filter(s -> !s.isBlank())
                .distinct()
                .collect(Collectors.joining(DEPT_SEPARATOR));
    }
}

package com.metrology.controller;

import com.metrology.dto.LoginRequest;
import com.metrology.dto.LoginResponse;
import com.metrology.dto.RegisterRequest;
import com.metrology.entity.User;
import com.metrology.repository.UserRepository;
import com.metrology.service.AuthService;
import com.metrology.service.PermissionService;
import com.metrology.service.UserFileGrantService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final UserRepository userRepository;
    private final PermissionService permissionService;
    private final UserFileGrantService userFileGrantService;

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest req) {
        try {
            return ResponseEntity.ok(authService.login(req));
        } catch (Exception e) {
            return ResponseEntity.status(401).body(Map.of("message", "用户名或密码错误"));
        }
    }

    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody RegisterRequest req) {
        try {
            return ResponseEntity.ok(authService.register(req));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    /** 获取当前登录用户的最新信息和权限（用于前端实时刷新权限） */
    @GetMapping("/me")
    public ResponseEntity<?> me(@AuthenticationPrincipal UserDetails userDetails) {
        User user = userRepository.findByUsername(userDetails.getUsername()).orElseThrow();
        List<String> departments = splitDepartments(user.getDepartment());
        return ResponseEntity.ok(new LoginResponse(
                null,
                user.getUsername(),
                user.getId(),
                user.getRole() != null ? user.getRole() : "USER",
                permissionService.getUserPermissions(user.getUsername()),
                user.getDepartment(),
                departments,
                userFileGrantService.getReadonlyFolders(user.getId())));
    }

    @PostMapping("/change-password")
    public ResponseEntity<?> changePassword(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody Map<String, String> body) {
        try {
            authService.changePassword(userDetails.getUsername(),
                    body.get("oldPassword"), body.get("newPassword"));
            return ResponseEntity.ok(Map.of("message", "密码修改成功"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("message", "旧密码错误"));
        }
    }

    @PostMapping("/change-username")
    public ResponseEntity<?> changeUsername(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody Map<String, String> body) {
        try {
            LoginResponse res = authService.changeUsername(userDetails.getUsername(), body.get("newUsername"));
            return ResponseEntity.ok(res);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    private List<String> splitDepartments(String stored) {
        if (stored == null || stored.isBlank()) return Collections.emptyList();
        return Arrays.stream(stored.replace('，', ',').split(","))
                .map(String::trim)
                .filter(s -> !s.isBlank())
                .distinct()
                .collect(Collectors.toList());
    }
}

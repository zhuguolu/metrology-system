package com.metrology.service;

import com.metrology.dto.LoginRequest;
import com.metrology.dto.LoginResponse;
import com.metrology.dto.RegisterRequest;
import com.metrology.entity.User;
import com.metrology.entity.UserSettings;
import com.metrology.repository.UserRepository;
import com.metrology.repository.UserSettingsRepository;
import com.metrology.security.JwtUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final UserSettingsRepository settingsRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final AuthenticationManager authManager;
    private final PermissionService permissionService;
    private final UserFileGrantService userFileGrantService;

    public LoginResponse login(LoginRequest req) {
        authManager.authenticate(
                new UsernamePasswordAuthenticationToken(req.getUsername(), req.getPassword()));
        User user = userRepository.findByUsername(req.getUsername()).orElseThrow();
        String token = jwtUtil.generateToken(user.getUsername());
        List<String> departments = splitDepartments(user.getDepartment());
        return new LoginResponse(token, user.getUsername(), user.getId(),
                user.getRole() != null ? user.getRole() : "USER",
                permissionService.getUserPermissions(user.getUsername()),
                user.getDepartment(),
                departments,
                userFileGrantService.getReadonlyFolders(user.getId()));
    }

    public LoginResponse register(RegisterRequest req) {
        if (req.getUsername() == null || req.getUsername().isBlank())
            throw new IllegalArgumentException("用户名不能为空");
        if (req.getPassword() == null || req.getPassword().isBlank())
            throw new IllegalArgumentException("密码不能为空");
        if (userRepository.existsByUsername(req.getUsername()))
            throw new IllegalArgumentException("用户名已存在");

        User user = new User();
        user.setUsername(req.getUsername().trim());
        user.setPassword(passwordEncoder.encode(req.getPassword()));
        user.setRole("USER");
        userRepository.save(user);

        UserSettings settings = new UserSettings();
        settings.setUserId(user.getId());
        settings.setWarningDays(315);
        settings.setExpiredDays(360);
        settings.setAutoLedgerExportEnabled(Boolean.FALSE);
        settings.setDatabaseBackupEnabled(Boolean.FALSE);
        settingsRepository.save(settings);

        String token = jwtUtil.generateToken(user.getUsername());
        List<String> departments = splitDepartments(user.getDepartment());
        return new LoginResponse(token, user.getUsername(), user.getId(), "USER",
                permissionService.getUserPermissions(user.getUsername()),
                user.getDepartment(),
                departments,
                userFileGrantService.getReadonlyFolders(user.getId()));
    }

    public void changePassword(String username, String oldPassword, String newPassword) {
        authManager.authenticate(new UsernamePasswordAuthenticationToken(username, oldPassword));
        User user = userRepository.findByUsername(username).orElseThrow();
        user.setPassword(passwordEncoder.encode(newPassword));
        userRepository.save(user);
    }

    public void resetPasswordByAdmin(Long userId, String newPassword) {
        if (newPassword == null || newPassword.isBlank()) {
            throw new IllegalArgumentException("密码不能为空");
        }
        if (newPassword.trim().length() < 6) {
            throw new IllegalArgumentException("密码至少6位");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));

        if ("ADMIN".equalsIgnoreCase(user.getRole())) {
            throw new IllegalArgumentException("管理员账号请通过本人修改密码");
        }

        user.setPassword(passwordEncoder.encode(newPassword.trim()));
        userRepository.save(user);
    }

    public LoginResponse changeUsername(String currentUsername, String newUsername) {
        if (newUsername == null || newUsername.isBlank()) throw new IllegalArgumentException("用户名不能为空");
        if (userRepository.existsByUsername(newUsername)) throw new IllegalArgumentException("用户名已存在");
        User user = userRepository.findByUsername(currentUsername).orElseThrow();
        user.setUsername(newUsername.trim());
        userRepository.save(user);
        String token = jwtUtil.generateToken(newUsername);
        List<String> departments = splitDepartments(user.getDepartment());
        return new LoginResponse(token, newUsername, user.getId(),
                user.getRole() != null ? user.getRole() : "USER",
                permissionService.getUserPermissions(newUsername),
                user.getDepartment(),
                departments,
                userFileGrantService.getReadonlyFolders(user.getId()));
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

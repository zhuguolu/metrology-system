package com.metrology.service;

import com.metrology.entity.User;
import com.metrology.repository.UserPermissionRepository;
import com.metrology.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class PermissionService {

    public static final String DEVICE_VIEW   = "DEVICE_VIEW";
    public static final String DEVICE_CREATE = "DEVICE_CREATE";
    public static final String DEVICE_UPDATE = "DEVICE_UPDATE";
    public static final String DEVICE_DELETE = "DEVICE_DELETE";
    public static final String CALIBRATION_RECORD = "CALIBRATION_RECORD";
    public static final String STATUS_MANAGE = "STATUS_MANAGE";
    public static final String USER_MANAGE   = "USER_MANAGE";
    public static final String FILE_ACCESS   = "FILE_ACCESS";
    public static final String WEBDAV_ACCESS = "WEBDAV_ACCESS";

    public static final List<String> ALL_PERMISSIONS = List.of(
            DEVICE_VIEW, DEVICE_CREATE, DEVICE_UPDATE, DEVICE_DELETE, CALIBRATION_RECORD,
            STATUS_MANAGE, USER_MANAGE, FILE_ACCESS, WEBDAV_ACCESS
    );

    private final UserRepository userRepository;
    private final UserPermissionRepository permissionRepository;
    private final UserFileGrantService userFileGrantService;

    public boolean hasPermission(String username, String permission) {
        User user = userRepository.findByUsername(username).orElse(null);
        if (user == null) return false;
        if ("ADMIN".equals(user.getRole())) return true;
        return permissionRepository.existsByUserIdAndPermission(user.getId(), permission);
    }

    public List<String> getUserPermissions(String username) {
        User user = userRepository.findByUsername(username).orElseThrow();
        if ("ADMIN".equals(user.getRole())) return ALL_PERMISSIONS;
        return permissionRepository.findByUserId(user.getId())
                .stream().map(p -> p.getPermission()).collect(Collectors.toList());
    }

    public boolean hasFileModuleAccess(String username) {
        return hasPermission(username, FILE_ACCESS) || userFileGrantService.hasReadonlyFolderAccess(username);
    }
}

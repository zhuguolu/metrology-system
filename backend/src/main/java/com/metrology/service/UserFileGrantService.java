package com.metrology.service;

import com.metrology.entity.User;
import com.metrology.entity.UserFile;
import com.metrology.entity.UserFileGrant;
import com.metrology.repository.UserFileGrantRepository;
import com.metrology.repository.UserFileRepository;
import com.metrology.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class UserFileGrantService {

    private final UserRepository userRepository;
    private final UserFileRepository userFileRepository;
    private final UserFileGrantRepository userFileGrantRepository;

    public boolean hasReadonlyFolderAccess(String username) {
        User user = userRepository.findByUsername(username).orElse(null);
        return user != null && !userFileGrantRepository.findByUserId(user.getId()).isEmpty();
    }

    public List<Long> getReadonlyFolderIds(Long userId) {
        return userFileGrantRepository.findByUserId(userId).stream()
                .map(UserFileGrant::getFolderId)
                .distinct()
                .toList();
    }

    public List<Map<String, Object>> getReadonlyFolders(String username) {
        User user = userRepository.findByUsername(username).orElse(null);
        if (user == null) {
            return List.of();
        }
        return getReadonlyFolders(user.getId());
    }

    public List<Map<String, Object>> getReadonlyFolders(Long userId) {
        List<Map<String, Object>> result = new ArrayList<>();
        for (Long folderId : getReadonlyFolderIds(userId)) {
            UserFile folder = userFileRepository.findById(folderId).orElse(null);
            if (folder == null || !"FOLDER".equals(folder.getType())) {
                continue;
            }
            result.add(toGrantSummary(folder));
        }
        result.sort(Comparator.comparing(item -> String.valueOf(item.get("folderPath")), String.CASE_INSENSITIVE_ORDER));
        return result;
    }

    public List<Map<String, Object>> listGrantableFolders(String username) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalArgumentException("用户不存在"));
        List<Map<String, Object>> options = new ArrayList<>();
        collectGrantableFolders(user.getUsername(), null, "", options);
        return options;
    }

    public void replaceReadonlyFolders(String operatorUsername, Long targetUserId, List<Long> folderIds) {
        Set<Long> uniqueFolderIds = new LinkedHashSet<>();
        if (folderIds != null) {
            uniqueFolderIds.addAll(folderIds.stream().filter(Objects::nonNull).toList());
        }

        List<UserFileGrant> next = new ArrayList<>();
        for (Long folderId : uniqueFolderIds) {
            UserFile folder = userFileRepository.findById(folderId)
                    .orElseThrow(() -> new IllegalArgumentException("授权文件夹不存在"));
            if (!"FOLDER".equals(folder.getType())) {
                throw new IllegalArgumentException("只支持授权文件夹只读访问");
            }
            if (!Objects.equals(folder.getUserId(), operatorUsername)) {
                throw new IllegalArgumentException("只能授权当前管理员自己的文件夹");
            }
            next.add(new UserFileGrant(null, targetUserId, folderId));
        }

        userFileGrantRepository.deleteByUserId(targetUserId);
        if (!next.isEmpty()) {
            userFileGrantRepository.saveAll(next);
        }
    }

    private void collectGrantableFolders(String ownerUsername, Long parentId, String parentPath, List<Map<String, Object>> options) {
        List<UserFile> folders = userFileRepository.findByUserIdAndParentIdOrderByTypeAscNameAsc(ownerUsername, parentId)
                .stream()
                .filter(file -> "FOLDER".equals(file.getType()))
                .toList();

        for (UserFile folder : folders) {
            String path = parentPath.isBlank() ? "/" + folder.getName() : parentPath + "/" + folder.getName();
            Map<String, Object> option = new LinkedHashMap<>();
            option.put("id", folder.getId());
            option.put("name", folder.getName());
            option.put("path", path);
            options.add(option);
            collectGrantableFolders(ownerUsername, folder.getId(), path, options);
        }
    }

    private Map<String, Object> toGrantSummary(UserFile folder) {
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("folderId", folder.getId());
        item.put("folderName", folder.getName());
        item.put("folderPath", buildFolderPath(folder));
        item.put("ownerUsername", folder.getUserId());
        return item;
    }

    private String buildFolderPath(UserFile folder) {
        List<String> segments = new ArrayList<>();
        UserFile current = folder;
        while (current != null) {
            segments.add(0, current.getName());
            if (current.getParentId() == null) {
                break;
            }
            current = userFileRepository.findById(current.getParentId()).orElse(null);
        }
        return "/" + String.join("/", segments);
    }
}

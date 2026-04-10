package com.metrology.service;

import com.metrology.entity.User;
import com.metrology.entity.UserFile;
import com.metrology.entity.UserFileGrant;
import com.metrology.repository.UserFileRepository;
import com.metrology.repository.UserFileGrantRepository;
import com.metrology.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.transaction.annotation.Transactional;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class UserFileService {

    private static final String TYPE_FOLDER = "FOLDER";
    private static final String TYPE_FILE = "FILE";

    private final UserFileRepository repo;
    private final UserRepository userRepository;
    private final UserFileGrantRepository userFileGrantRepository;
    private final PasswordEncoder passwordEncoder;
    private final PermissionService permissionService;

    @Value("${upload.path:/app/uploads}")
    private String uploadPath;

    public Map<String, Object> list(String username, Long parentId) {
        User user = getUserByUsername(username);
        boolean fullAccess = permissionService.hasPermission(username, PermissionService.FILE_ACCESS);

        if (parentId == null) {
            List<UserFile> result = new ArrayList<>();
            if (fullAccess) {
                result.addAll(repo.findByUserIdAndParentIdOrderByTypeAscNameAsc(username, null)
                        .stream()
                        .map(item -> applyAccessMetadata(item, false, null))
                        .toList());
            }
            result.addAll(loadGrantedRootFolders(user.getId(), fullAccess ? result : null));
            result.sort(fileComparator());
            return buildListResult(result, !fullAccess, fullAccess);
        }

        UserFile folder = repo.findById(parentId).orElseThrow(() -> new IllegalArgumentException("文件夹不存在"));
        if (!TYPE_FOLDER.equals(folder.getType())) {
            throw new IllegalArgumentException("目标位置必须是文件夹");
        }

        if (fullAccess && Objects.equals(folder.getUserId(), username)) {
            List<UserFile> items = repo.findByUserIdAndParentIdOrderByTypeAscNameAsc(username, parentId)
                    .stream()
                    .map(item -> applyAccessMetadata(item, false, null))
                    .toList();
            return buildListResult(items, false, true);
        }

        UserFile grantRoot = findGrantRoot(user.getId(), folder.getId());
        if (grantRoot == null) {
            throw new IllegalArgumentException("闁哄啰濮靛鍫㈡媼閸ф锛栭悹鍥ュ劜閺嬪啯绂掔捄鎭掍粴");
        }

        List<UserFile> items = repo.findByParentIdOrderByTypeAscNameAsc(folder.getId())
                .stream()
                .map(item -> applyAccessMetadata(item, true, grantRoot))
                .toList();
        return buildListResult(items, true, false);
    }

    public List<UserFile> search(String username, String q) {
        if (q == null || q.isBlank()) return List.of();
        User user = getUserByUsername(username);
        boolean fullAccess = permissionService.hasPermission(username, PermissionService.FILE_ACCESS);
        Map<Long, UserFile> results = new LinkedHashMap<>();

        if (fullAccess) {
            for (UserFile item : repo.findByUserIdAndNameContainingIgnoreCaseOrderByTypeAscNameAsc(username, q)) {
                results.put(item.getId(), applyAccessMetadata(item, false, null));
            }
        }

        Set<Long> grantRoots = Set.copyOf(userFileGrantRepository.findByUserId(user.getId()).stream()
                .map(UserFileGrant::getFolderId)
                .toList());
        if (!grantRoots.isEmpty()) {
            for (UserFile item : repo.findByNameContainingIgnoreCaseOrderByTypeAscNameAsc(q)) {
                if (results.containsKey(item.getId())) {
                    continue;
                }
                UserFile grantRoot = findGrantRoot(user.getId(), item.getId());
                if (grantRoot != null && grantRoots.contains(grantRoot.getId())) {
                    results.put(item.getId(), applyAccessMetadata(item, true, grantRoot));
                }
            }
        }

        return results.values().stream().sorted(fileComparator()).toList();
    }

    public UserFile getFile(String username, Long id) {
        UserFile file = repo.findById(id).orElseThrow(() -> new IllegalArgumentException("文件不存在"));
        boolean fullAccess = permissionService.hasPermission(username, PermissionService.FILE_ACCESS);
        if (fullAccess && Objects.equals(file.getUserId(), username)) {
            return applyAccessMetadata(file, false, null);
        }

        User user = getUserByUsername(username);
        UserFile grantRoot = findGrantRoot(user.getId(), id);
        if (grantRoot != null) {
            return applyAccessMetadata(file, true, grantRoot);
        }

        throw new IllegalArgumentException("无权访问该文件");
    }

    public UserFile createFolder(String userId, Long parentId, String name) {
        if (name == null || name.isBlank()) throw new IllegalArgumentException("文件夹名称不能为空");
        if (parentId != null) {
            UserFile parent = getOwnedFile(userId, parentId);
            if (!TYPE_FOLDER.equals(parent.getType())) {
                throw new IllegalArgumentException("目标位置必须是文件夹");
            }
        }
        if (repo.existsByUserIdAndParentIdAndName(userId, parentId, name.trim())) {
            throw new IllegalArgumentException("同名文件夹已存在");
        }
        UserFile file = new UserFile();
        file.setUserId(userId);
        file.setParentId(parentId);
        file.setName(name.trim());
        file.setType(TYPE_FOLDER);
        file.setShareEnabled(false);
        file.setShareAllowDownload(true);
        UserFile saved = repo.save(file);
        String relativePath = buildFolderRelativePath(saved.getParentId(), saved.getName());
        ensureDirectoryExists(relativePath);
        saved.setFilePath(relativePath);
        return repo.save(saved);
    }

    public UserFile uploadFile(String userId, Long parentId, MultipartFile file) throws IOException {
        String parentRelativePath = userFilesRootPath();
        if (parentId != null) {
            UserFile parent = getOwnedFile(userId, parentId);
            if (!TYPE_FOLDER.equals(parent.getType())) {
                throw new IllegalArgumentException("目标位置必须是文件夹");
            }
            parentRelativePath = ensureFolderPhysicalPath(parent);
        }

        File dir = resolveStorageFile(parentRelativePath);
        if (!dir.exists() && !dir.mkdirs()) {
            throw new IOException("创建上传目录失败");
        }

        String original = file.getOriginalFilename() != null ? file.getOriginalFilename() : "file";
        String relativeFilePath = buildUniqueFilePath(parentRelativePath, original);
        File dest = resolveStorageFile(relativeFilePath);
        file.transferTo(dest);

        UserFile entity = new UserFile();
        entity.setUserId(userId);
        entity.setParentId(parentId);
        entity.setName(original);
        entity.setType(TYPE_FILE);
        entity.setFilePath(relativeFilePath);
        entity.setFileSize(file.getSize());
        entity.setMimeType(file.getContentType());
        entity.setShareEnabled(false);
        entity.setShareAllowDownload(true);
        return repo.save(entity);
    }

    public UserFile rename(String userId, Long id, String newName) {
        if (newName == null || newName.isBlank()) throw new IllegalArgumentException("名称不能为空");
        UserFile file = getOwnedFile(userId, id);
        if (repo.existsByUserIdAndParentIdAndName(userId, file.getParentId(), newName.trim())
                && !Objects.equals(file.getName(), newName.trim())) {
            throw new IllegalArgumentException("当前目录中已存在同名文件或文件夹");
        }
        if (TYPE_FOLDER.equals(file.getType())) {
            relocateFolderTree(file, file.getParentId(), newName.trim());
        } else {
            relocateFile(file, file.getParentId(), newName.trim());
        }
        file.setName(newName.trim());
        return repo.save(file);
    }

    public UserFile move(String userId, Long id, Long parentId) {
        UserFile file = getOwnedFile(userId, id);
        if (Objects.equals(file.getParentId(), parentId)) {
            return file;
        }
        if (Objects.equals(file.getId(), parentId)) {
            throw new IllegalArgumentException("不能移动到自身");
        }

        if (parentId != null) {
            UserFile targetFolder = getOwnedFile(userId, parentId);
            if (!TYPE_FOLDER.equals(targetFolder.getType())) {
                throw new IllegalArgumentException("目标位置必须是文件夹");
            }
            if (TYPE_FOLDER.equals(file.getType()) && isDescendantOf(file.getId(), parentId)) {
                throw new IllegalArgumentException("不能把文件夹移动到它的子文件夹中");
            }
        }

        if (repo.existsByUserIdAndParentIdAndName(userId, parentId, file.getName())) {
            throw new IllegalArgumentException("目标文件夹中已存在同名文件或文件夹");
        }

        if (TYPE_FOLDER.equals(file.getType())) {
            relocateFolderTree(file, parentId, file.getName());
        } else {
            relocateFile(file, parentId, file.getName());
        }
        file.setParentId(parentId);
        return repo.save(file);
    }

    public void delete(String userId, Long id) {
        UserFile file = getOwnedFile(userId, id);
        if (TYPE_FOLDER.equals(file.getType())) {
            deleteChildrenRecursive(file.getId());
            deleteDirectoryIfExists(resolveFolderPath(file));
        } else {
            deletePhysicalFile(file);
        }
        repo.deleteById(file.getId());
    }
    public byte[] downloadFile(Long id) throws IOException {
        return Files.readAllBytes(resolveDownloadTarget(id).toPath());
    }

    public File resolveDownloadTarget(Long id) {
        UserFile file = repo.findById(id).orElseThrow(() -> new IllegalArgumentException("文件不存在"));
        return resolveDownloadTarget(file);
    }

    public File resolveDownloadTarget(UserFile file) {
        if (!TYPE_FILE.equals(file.getType())) {
            throw new IllegalArgumentException("该项不是文件");
        }
        File target = resolveStorageFile(file.getFilePath());
        if (!target.exists() || !target.isFile()) {
            throw new IllegalArgumentException("文件已被移除");
        }
        return target;
    }

    public List<Map<String, Object>> getBreadcrumb(String username, Long folderId) {
        List<Map<String, Object>> crumbs = new ArrayList<>();
        if (folderId == null) {
            return crumbs;
        }

        User user = getUserByUsername(username);
        boolean fullAccess = permissionService.hasPermission(username, PermissionService.FILE_ACCESS);
        UserFile currentFolder = repo.findById(folderId).orElseThrow(() -> new IllegalArgumentException("文件夹不存在"));
        UserFile grantRoot = (!fullAccess || !Objects.equals(currentFolder.getUserId(), username))
                ? findGrantRoot(user.getId(), folderId)
                : null;

        if (!(fullAccess && Objects.equals(currentFolder.getUserId(), username)) && grantRoot == null) {
            throw new IllegalArgumentException("闁哄啰濮靛鍫㈡媼閸ф锛栭悹鍥ュ劜閺嬪啯绂掔捄鎭掍粴");
        }

        Long current = folderId;
        while (current != null) {
            Optional<UserFile> opt = repo.findById(current);
            if (opt.isEmpty()) break;
            UserFile file = opt.get();
            Map<String, Object> crumb = new LinkedHashMap<>();
            crumb.put("id", file.getId());
            crumb.put("name", file.getName());
            crumb.put("readOnly", grantRoot != null);
            crumbs.add(0, crumb);
            if (grantRoot != null && Objects.equals(file.getId(), grantRoot.getId())) {
                break;
            }
            current = file.getParentId();
        }
        return crumbs;
    }

    @Transactional
    public Map<String, Object> scanSync(String userId, Long parentId) {
        String relativePath = resolveParentRelativePathForScan(userId, parentId);
        ensureDirectoryExists(relativePath);

        ScanStats stats = new ScanStats();
        scanDirectoryRecursive(userId, parentId, relativePath, stats);

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("path", relativePath);
        result.put("foldersCreated", stats.foldersCreated);
        result.put("foldersUpdated", stats.foldersUpdated);
        result.put("filesCreated", stats.filesCreated);
        result.put("filesUpdated", stats.filesUpdated);
        result.put("foldersDeleted", stats.foldersDeleted);
        result.put("filesDeleted", stats.filesDeleted);
        result.put("unchanged", stats.unchanged);
        result.put("conflicts", stats.conflicts);
        return result;
    }

    public Map<String, Object> getShareConfig(String userId, Long folderId) {
        UserFile folder = getOwnedFolder(userId, folderId);
        return toShareConfig(folder);
    }

    public List<Map<String, Object>> listGrantableFolders(String username) {
        List<Map<String, Object>> options = new ArrayList<>();
        collectGrantableFolders(username, null, "", options);
        return options;
    }

    public Map<String, Object> saveShare(
            String userId,
            Long folderId,
            Boolean allowDownload,
            LocalDateTime expiresAt,
            Boolean passwordProtected,
            String password,
            String customShareToken
    ) {
        UserFile folder = getOwnedFolder(userId, folderId);
        User user = getUserByUsername(userId);
        boolean isAdmin = "ADMIN".equalsIgnoreCase(user.getRole());
        if (expiresAt != null && expiresAt.isBefore(LocalDateTime.now())) {
            throw new IllegalArgumentException("分享失效时间不能早于当前时间");
        }

        if (isAdmin && hasText(customShareToken)) {
            folder.setShareToken(normalizeCustomShareToken(customShareToken, folder.getId()));
        } else if (!hasText(folder.getShareToken())) {
            folder.setShareToken(generateShareToken());
        }

        folder.setShareEnabled(true);
        folder.setShareAllowDownload(Boolean.TRUE.equals(allowDownload));
        folder.setShareExpiresAt(expiresAt);

        if (Boolean.TRUE.equals(passwordProtected)) {
            if (hasText(password)) {
                folder.setSharePasswordHash(passwordEncoder.encode(password.trim()));
            } else if (!hasText(folder.getSharePasswordHash())) {
                throw new IllegalArgumentException("请设置访问密码");
            }
        } else {
            folder.setSharePasswordHash(null);
        }

        return toShareConfig(repo.save(folder));
    }

    public void disableShare(String userId, Long folderId) {
        UserFile folder = getOwnedFolder(userId, folderId);
        folder.setShareEnabled(false);
        folder.setShareToken(null);
        folder.setSharePasswordHash(null);
        folder.setShareExpiresAt(null);
        folder.setShareAllowDownload(true);
        repo.save(folder);
    }

    public Map<String, Object> getPublicShare(String shareToken, Long folderId, String password) {
        UserFile rootFolder = getSharedRootFolder(shareToken);
        validateSharePassword(rootFolder, password);
        UserFile currentFolder = resolveSharedFolder(rootFolder, folderId);

        List<Map<String, Object>> items = repo.findByParentIdOrderByTypeAscNameAsc(currentFolder.getId())
                .stream()
                .map(this::toPublicItem)
                .toList();

        Map<String, Object> share = new LinkedHashMap<>();
        share.put("token", rootFolder.getShareToken());
        share.put("folderId", rootFolder.getId());
        share.put("folderName", rootFolder.getName());
        share.put("allowDownload", !Boolean.FALSE.equals(rootFolder.getShareAllowDownload()));
        share.put("hasPassword", hasText(rootFolder.getSharePasswordHash()));
        share.put("expiresAt", rootFolder.getShareExpiresAt());

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("share", share);
        result.put("currentFolderId", currentFolder.getId());
        result.put("currentFolderName", currentFolder.getName());
        result.put("breadcrumbs", getShareBreadcrumb(rootFolder, currentFolder));
        result.put("items", items);
        return result;
    }

    public UserFile getPublicSharedFile(String shareToken, Long fileId, String password, boolean requireDownload) {
        UserFile rootFolder = getSharedRootFolder(shareToken);
        validateSharePassword(rootFolder, password);
        if (requireDownload && Boolean.FALSE.equals(rootFolder.getShareAllowDownload())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "该分享未开放下载");
        }

        UserFile file = repo.findById(fileId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "文件不存在"));
        if (!TYPE_FILE.equals(file.getType())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "该项不是文件");
        }
        if (!isWithinTree(rootFolder.getId(), file.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "无权访问该文件");
        }
        return file;
    }

    private Map<String, Object> toShareConfig(UserFile folder) {
        Map<String, Object> result = new LinkedHashMap<>();
        boolean enabled = Boolean.TRUE.equals(folder.getShareEnabled()) && hasText(folder.getShareToken());
        result.put("enabled", enabled);
        result.put("token", folder.getShareToken());
        result.put("hasPassword", hasText(folder.getSharePasswordHash()));
        result.put("allowDownload", !Boolean.FALSE.equals(folder.getShareAllowDownload()));
        result.put("expiresAt", folder.getShareExpiresAt());
        result.put("folderId", folder.getId());
        result.put("folderName", folder.getName());
        return result;
    }

    private List<Map<String, Object>> getShareBreadcrumb(UserFile rootFolder, UserFile currentFolder) {
        List<Map<String, Object>> crumbs = new ArrayList<>();
        Long current = currentFolder.getId();
        while (current != null) {
            UserFile file = repo.findById(current).orElse(null);
            if (file == null) break;
            Map<String, Object> crumb = new LinkedHashMap<>();
            crumb.put("id", file.getId());
            crumb.put("name", file.getName());
            crumbs.add(0, crumb);
            if (Objects.equals(file.getId(), rootFolder.getId())) {
                break;
            }
            current = file.getParentId();
        }
        return crumbs;
    }

    private Map<String, Object> toPublicItem(UserFile file) {
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("id", file.getId());
        item.put("parentId", file.getParentId());
        item.put("name", file.getName());
        item.put("type", file.getType());
        item.put("fileSize", file.getFileSize());
        item.put("mimeType", file.getMimeType());
        item.put("createdAt", file.getCreatedAt());
        item.put("isFolder", TYPE_FOLDER.equals(file.getType()));
        return item;
    }

    private UserFile getOwnedFolder(String userId, Long id) {
        UserFile folder = getOwnedFile(userId, id);
        if (!TYPE_FOLDER.equals(folder.getType())) {
            throw new IllegalArgumentException("濞寸姴鎳忛弫顕€骞愭担绋跨€诲ù婊庡亝閺嬪啯绂掔捄鎭掍粴");
        }
        return folder;
    }

    private UserFile getOwnedFile(String userId, Long id) {
        UserFile file = repo.findById(id).orElseThrow(() -> new IllegalArgumentException("文件不存在"));
        if (!Objects.equals(file.getUserId(), userId)) {
            throw new IllegalArgumentException("无权访问该文件");
        }
        return file;
    }

    private UserFile getSharedRootFolder(String shareToken) {
        if (!hasText(shareToken)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "分享目录不存在");
        }
        UserFile rootFolder = repo.findByShareTokenAndTypeAndShareEnabledTrue(shareToken, TYPE_FOLDER)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "分享目录不存在"));
        if (rootFolder.getShareExpiresAt() != null && rootFolder.getShareExpiresAt().isBefore(LocalDateTime.now())) {
            throw new ResponseStatusException(HttpStatus.GONE, "分享已失效");
        }
        return rootFolder;
    }

    private void validateSharePassword(UserFile rootFolder, String password) {
        if (!hasText(rootFolder.getSharePasswordHash())) {
            return;
        }
        if (!hasText(password)) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "访问密码错误");
        }
        if (!passwordEncoder.matches(password, rootFolder.getSharePasswordHash())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "闁告帒妫旈棅鈺冣偓闈涙閻栨粓鏌ㄥ▎鎺濆殩");
        }
    }

    private UserFile resolveSharedFolder(UserFile rootFolder, Long folderId) {
        if (folderId == null || Objects.equals(folderId, rootFolder.getId())) {
            return rootFolder;
        }
        UserFile folder = repo.findById(folderId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "文件夹不存在"));
        if (!TYPE_FOLDER.equals(folder.getType()) || !isWithinTree(rootFolder.getId(), folder.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "无权访问该目录");
        }
        return folder;
    }

    private User getUserByUsername(String username) {
        return userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalArgumentException("文件不存在"));
    }

    private Map<String, Object> buildListResult(List<UserFile> items, boolean readOnly, boolean canWrite) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("items", items.stream().map(this::toFileItemPayload).toList());
        result.put("access", Map.of(
                "readOnly", readOnly,
                "canWrite", canWrite
        ));
        return result;
    }

    private Comparator<UserFile> fileComparator() {
        return Comparator
                .comparing((UserFile file) -> TYPE_FILE.equals(file.getType()))
                .thenComparing(file -> safeLowerName(file.getName()));
    }

    private List<UserFile> loadGrantedRootFolders(Long userId, List<UserFile> existingItems) {
        Set<Long> existingIds = existingItems == null
                ? Set.of()
                : existingItems.stream().map(UserFile::getId).collect(java.util.stream.Collectors.toSet());
        List<UserFile> granted = new ArrayList<>();
        for (UserFileGrant grant : userFileGrantRepository.findByUserId(userId)) {
            UserFile folder = repo.findById(grant.getFolderId()).orElse(null);
            if (folder == null || !TYPE_FOLDER.equals(folder.getType()) || existingIds.contains(folder.getId())) {
                continue;
            }
            granted.add(applyAccessMetadata(folder, true, folder));
        }
        return granted;
    }

    private UserFile findGrantRoot(Long userId, Long nodeId) {
        Long current = nodeId;
        while (current != null) {
            if (userFileGrantRepository.existsByUserIdAndFolderId(userId, current)) {
                return repo.findById(current).orElse(null);
            }
            UserFile currentNode = repo.findById(current).orElse(null);
            if (currentNode == null) {
                return null;
            }
            current = currentNode.getParentId();
        }
        return null;
    }

    private UserFile applyAccessMetadata(UserFile file, boolean readOnly, UserFile grantRoot) {
        file.setReadOnly(readOnly);
        file.setShared(readOnly);
        file.setGrantRootId(grantRoot != null ? grantRoot.getId() : null);
        file.setSharedOwner(readOnly && grantRoot != null ? grantRoot.getUserId() : null);
        return file;
    }

    private void scanDirectoryRecursive(String userId, Long parentId, String relativePath, ScanStats stats) {
        File directory = resolveStorageFile(relativePath);
        File[] children = directory.listFiles();
        if (children == null) {
            return;
        }

        Arrays.sort(children, Comparator
                .comparing(File::isFile)
                .thenComparing(file -> safeLowerName(file.getName())));

        Map<String, UserFile> existingByName = new LinkedHashMap<>();
        for (UserFile existing : repo.findByUserIdAndParentIdOrderByTypeAscNameAsc(userId, parentId)) {
            existingByName.putIfAbsent(existing.getName(), existing);
        }
        Set<String> scannedNames = new HashSet<>();

        for (File child : children) {
            String childName = child.getName();
            scannedNames.add(childName);
            String childRelativePath = joinPath(relativePath, childName);
            UserFile existing = existingByName.remove(childName);

            if (child.isDirectory()) {
                if (existing != null && !TYPE_FOLDER.equals(existing.getType())) {
                    stats.conflicts += 1;
                    continue;
                }

                UserFile folder = existing;
                boolean changed = false;
                if (folder == null) {
                    folder = new UserFile();
                    folder.setUserId(userId);
                    folder.setParentId(parentId);
                    folder.setName(childName);
                    folder.setType(TYPE_FOLDER);
                    folder.setFilePath(childRelativePath);
                    folder.setShareEnabled(false);
                    folder.setShareAllowDownload(true);
                    folder = repo.save(folder);
                    stats.foldersCreated += 1;
                } else if (!Objects.equals(normalizeRelativePath(folder.getFilePath()), normalizeRelativePath(childRelativePath))) {
                    folder.setFilePath(childRelativePath);
                    changed = true;
                }

                if (changed) {
                    repo.save(folder);
                    stats.foldersUpdated += 1;
                } else if (existing != null) {
                    stats.unchanged += 1;
                }

                ensureDirectoryExists(childRelativePath);
                scanDirectoryRecursive(userId, folder.getId(), childRelativePath, stats);
                continue;
            }

            if (!child.isFile()) {
                continue;
            }

            if (existing != null && !TYPE_FILE.equals(existing.getType())) {
                stats.conflicts += 1;
                continue;
            }

            String mimeType = detectMimeType(child.toPath(), childName);
            long fileSize = child.length();

            if (existing == null) {
                UserFile file = new UserFile();
                file.setUserId(userId);
                file.setParentId(parentId);
                file.setName(childName);
                file.setType(TYPE_FILE);
                file.setFilePath(childRelativePath);
                file.setFileSize(fileSize);
                file.setMimeType(mimeType);
                file.setShareEnabled(false);
                file.setShareAllowDownload(true);
                repo.save(file);
                stats.filesCreated += 1;
                continue;
            }

            boolean changed = false;
            if (!Objects.equals(normalizeRelativePath(existing.getFilePath()), normalizeRelativePath(childRelativePath))) {
                existing.setFilePath(childRelativePath);
                changed = true;
            }
            if (!Objects.equals(existing.getFileSize(), fileSize)) {
                existing.setFileSize(fileSize);
                changed = true;
            }
            if (!Objects.equals(normalizeNullableText(existing.getMimeType()), normalizeNullableText(mimeType))) {
                existing.setMimeType(mimeType);
                changed = true;
            }

            if (changed) {
                repo.save(existing);
                stats.filesUpdated += 1;
            } else {
                stats.unchanged += 1;
            }
        }

        for (Map.Entry<String, UserFile> staleEntry : existingByName.entrySet()) {
            if (scannedNames.contains(staleEntry.getKey())) {
                continue;
            }
            removeStaleEntryRecursive(staleEntry.getValue(), stats);
        }
    }

    private void removeStaleEntryRecursive(UserFile stale, ScanStats stats) {
        if (stale == null || stale.getId() == null) {
            return;
        }
        if (TYPE_FOLDER.equals(stale.getType())) {
            for (UserFile child : repo.findByParentId(stale.getId())) {
                removeStaleEntryRecursive(child, stats);
            }
            repo.deleteById(stale.getId());
            stats.foldersDeleted += 1;
            return;
        }

        repo.deleteById(stale.getId());
        stats.filesDeleted += 1;
    }

    private void collectGrantableFolders(String ownerUsername, Long parentId, String parentPath, List<Map<String, Object>> options) {
        List<UserFile> folders = repo.findByUserIdAndParentIdOrderByTypeAscNameAsc(ownerUsername, parentId)
                .stream()
                .filter(file -> TYPE_FOLDER.equals(file.getType()))
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

    private void relocateFile(UserFile file, Long targetParentId, String targetName) {
        String targetParentPath = resolveParentRelativePath(targetParentId);
        String currentPath = normalizeRelativePath(file.getFilePath());
        String targetPath = joinPath(targetParentPath, sanitizeFileName(targetName));
        if (Objects.equals(currentPath, targetPath)) {
            file.setFilePath(targetPath);
            return;
        }
        moveFileIfExists(currentPath, targetPath);
        file.setFilePath(targetPath);
    }

    private void relocateFolderTree(UserFile folder, Long targetParentId, String targetName) {
        String oldPath = resolveFolderPath(folder);
        String newPath = buildFolderRelativePath(targetParentId, targetName);
        if (Objects.equals(oldPath, newPath)) {
            ensureDirectoryExists(newPath);
            folder.setFilePath(newPath);
            return;
        }

        boolean movedWholeDirectory = moveDirectoryIfExists(oldPath, newPath);
        folder.setFilePath(newPath);
        repo.save(folder);

        if (movedWholeDirectory) {
            updateDescendantPathsAfterDirectoryMove(folder.getId(), oldPath, newPath);
        } else {
            ensureDirectoryExists(newPath);
            migrateDescendantsToFolderTree(folder.getId(), oldPath, newPath);
        }
    }

    private void updateDescendantPathsAfterDirectoryMove(Long folderId, String oldPrefix, String newPrefix) {
        repo.findByParentId(folderId).forEach(child -> {
            String childCurrentPath = TYPE_FOLDER.equals(child.getType())
                    ? resolveFolderPath(child)
                    : normalizeRelativePath(child.getFilePath());
            String updatedPath = replacePathPrefix(childCurrentPath, oldPrefix, newPrefix);
            child.setFilePath(updatedPath);
            repo.save(child);
            if (TYPE_FOLDER.equals(child.getType())) {
                updateDescendantPathsAfterDirectoryMove(child.getId(), childCurrentPath, updatedPath);
            }
        });
    }

    private void migrateDescendantsToFolderTree(Long folderId, String oldPrefix, String newPrefix) {
        repo.findByParentId(folderId).forEach(child -> {
            if (TYPE_FOLDER.equals(child.getType())) {
                String childOldPath = resolveFolderPath(child);
                String childNewPath = joinPath(newPrefix, sanitizePathSegment(child.getName()));
                boolean movedDir = moveDirectoryIfExists(childOldPath, childNewPath);
                child.setFilePath(childNewPath);
                repo.save(child);
                if (movedDir) {
                    updateDescendantPathsAfterDirectoryMove(child.getId(), childOldPath, childNewPath);
                } else {
                    ensureDirectoryExists(childNewPath);
                    migrateDescendantsToFolderTree(child.getId(), childOldPath, childNewPath);
                }
            } else {
                String oldFilePath = normalizeRelativePath(child.getFilePath());
                String newFilePath = joinPath(newPrefix, sanitizeFileName(child.getName()));
                moveFileIfExists(oldFilePath, newFilePath);
                child.setFilePath(newFilePath);
                repo.save(child);
            }
        });
    }

    private void deleteChildrenRecursive(Long parentId) {
        repo.findByParentId(parentId).forEach(child -> {
            if (TYPE_FOLDER.equals(child.getType())) {
                deleteChildrenRecursive(child.getId());
                deleteDirectoryIfExists(resolveFolderPath(child));
            } else {
                deletePhysicalFile(child);
            }
            repo.deleteById(child.getId());
        });
    }

    private void deletePhysicalFile(UserFile file) {
        if (file.getFilePath() != null) {
            new File(uploadPath + file.getFilePath()).delete();
        }
    }

    private boolean isDescendantOf(Long folderId, Long targetParentId) {
        Long current = targetParentId;
        while (current != null) {
            Optional<UserFile> opt = repo.findById(current);
            if (opt.isEmpty()) {
                return false;
            }
            UserFile node = opt.get();
            if (Objects.equals(node.getId(), folderId)) {
                return true;
            }
            current = node.getParentId();
        }
        return false;
    }

    private boolean isWithinTree(Long rootId, Long nodeId) {
        Long current = nodeId;
        while (current != null) {
            Optional<UserFile> opt = repo.findById(current);
            if (opt.isEmpty()) {
                return false;
            }
            UserFile node = opt.get();
            if (Objects.equals(node.getId(), rootId)) {
                return true;
            }
            current = node.getParentId();
        }
        return false;
    }

    private String generateShareToken() {
        String token;
        do {
            token = UUID.randomUUID().toString().replace("-", "");
        } while (repo.existsByShareToken(token));
        return token;
    }

    private String normalizeCustomShareToken(String rawToken, Long currentId) {
        String token = rawToken == null ? "" : rawToken.trim();
        if (!hasText(token)) {
            throw new IllegalArgumentException("閻犲洨鏌夐鏇犵磾椤旂厧鐎诲ù婊庡亰閹藉ジ骞掗妷銉﹀€电紓鍌楀亾");
        }
        if (token.length() < 4 || token.length() > 64) {
            throw new IllegalArgumentException("分享后缀长度需在 4 到 64 个字符之间");
        }
        if (!token.matches("[A-Za-z0-9_-]+")) {
            throw new IllegalArgumentException("分享后缀仅支持字母、数字、中划线和下划线");
        }
        if (repo.existsByShareTokenAndIdNot(token, currentId)) {
            throw new IllegalArgumentException("该分享后缀已被占用，请更换一个");
        }
        return token;
    }

    private String userFilesRootPath() {
        return "/user-files";
    }

    private String resolveParentRelativePathForScan(String userId, Long parentId) {
        if (parentId == null) {
            ensureDirectoryExists(userFilesRootPath());
            return userFilesRootPath();
        }
        UserFile parent = getOwnedFolder(userId, parentId);
        return ensureFolderPhysicalPath(parent);
    }

    private String resolveParentRelativePath(Long parentId) {
        if (parentId == null) {
            ensureDirectoryExists(userFilesRootPath());
            return userFilesRootPath();
        }
        UserFile parent = repo.findById(parentId).orElseThrow(() -> new IllegalArgumentException("文件夹不存在"));
        if (!TYPE_FOLDER.equals(parent.getType())) {
            throw new IllegalArgumentException("目标位置必须是文件夹");
        }
        return ensureFolderPhysicalPath(parent);
    }

    private String ensureFolderPhysicalPath(UserFile folder) {
        String relativePath = resolveFolderPath(folder);
        ensureDirectoryExists(relativePath);
        if (!Objects.equals(normalizeRelativePath(folder.getFilePath()), relativePath)) {
            folder.setFilePath(relativePath);
            repo.save(folder);
        }
        return relativePath;
    }

    private String resolveFolderPath(UserFile folder) {
        if (hasText(folder.getFilePath())) {
            return normalizeRelativePath(folder.getFilePath());
        }
        return buildFolderRelativePath(folder.getParentId(), folder.getName());
    }

    private String buildFolderRelativePath(Long parentId, String folderName) {
        String parentPath = parentId == null ? userFilesRootPath() : ensureFolderPhysicalPath(
                repo.findById(parentId).orElseThrow(() -> new IllegalArgumentException("父文件夹不存在"))
        );
        return joinPath(parentPath, sanitizePathSegment(folderName));
    }

    private String buildUniqueFilePath(String parentRelativePath, String originalName) {
        String sanitizedName = sanitizeFileName(originalName);
        if (!sanitizedName.contains(".")) {
            String ext = getExtension(originalName);
            if (hasText(ext)) {
                sanitizedName = sanitizedName + "." + ext;
            }
        }
        String baseName = sanitizedName;
        String extension = "";
        int dotIndex = sanitizedName.lastIndexOf('.');
        if (dotIndex > 0) {
            baseName = sanitizedName.substring(0, dotIndex);
            extension = sanitizedName.substring(dotIndex);
        }

        String candidate = joinPath(parentRelativePath, sanitizedName);
        int suffix = 1;
        while (resolveStorageFile(candidate).exists()) {
            candidate = joinPath(parentRelativePath, baseName + "-" + suffix + extension);
            suffix += 1;
        }
        return candidate;
    }

    private String sanitizePathSegment(String name) {
        String sanitized = (name == null ? "" : name.trim())
                .replaceAll("[\\\\/:*?\"<>|]", "_")
                .replaceAll("\\s+", " ");
        return sanitized.isBlank() ? "未命名文件夹" : sanitized;
    }

    private String sanitizeFileName(String name) {
        String raw = name == null ? "file" : name.trim();
        String ext = getExtension(raw);
        String base = raw;
        int dotIndex = raw.lastIndexOf('.');
        if (dotIndex > 0) {
            base = raw.substring(0, dotIndex);
        }
        String sanitizedBase = base.replaceAll("[\\\\/:*?\"<>|]", "_").replaceAll("\\s+", " ").trim();
        if (sanitizedBase.isBlank()) {
            sanitizedBase = "file";
        }
        return hasText(ext) ? sanitizedBase + "." + ext : sanitizedBase;
    }

    private String getExtension(String name) {
        if (name == null) return "";
        int dotIndex = name.lastIndexOf('.');
        if (dotIndex <= 0 || dotIndex == name.length() - 1) {
            return "";
        }
        return name.substring(dotIndex + 1);
    }

    private String joinPath(String parent, String child) {
        String normalizedParent = normalizeRelativePath(parent);
        if (normalizedParent.endsWith("/")) {
            return normalizedParent + child;
        }
        return normalizedParent + "/" + child;
    }

    private String normalizeRelativePath(String relativePath) {
        if (!hasText(relativePath)) {
            return userFilesRootPath();
        }
        return relativePath.startsWith("/") ? relativePath : "/" + relativePath;
    }

    private File resolveStorageFile(String relativePath) {
        return new File(uploadPath + normalizeRelativePath(relativePath));
    }

    private void ensureDirectoryExists(String relativePath) {
        File dir = resolveStorageFile(relativePath);
        if (!dir.exists()) {
            dir.mkdirs();
        }
    }

    private boolean moveDirectoryIfExists(String fromRelativePath, String toRelativePath) {
        File source = resolveStorageFile(fromRelativePath);
        if (!source.exists()) {
            return false;
        }
        File target = resolveStorageFile(toRelativePath);
        File parent = target.getParentFile();
        if (parent != null && !parent.exists()) {
            parent.mkdirs();
        }
        try {
            Files.move(source.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING);
            return true;
        } catch (IOException e) {
            return false;
        }
    }

    private void moveFileIfExists(String fromRelativePath, String toRelativePath) {
        File source = resolveStorageFile(fromRelativePath);
        if (!source.exists()) {
            return;
        }
        File target = resolveStorageFile(toRelativePath);
        File parent = target.getParentFile();
        if (parent != null && !parent.exists()) {
            parent.mkdirs();
        }
        try {
            Files.move(source.toPath(), target.toPath(), StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException e) {
            throw new IllegalArgumentException("文件读取失败");
        }
    }

    private void deleteDirectoryIfExists(String relativePath) {
        File dir = resolveStorageFile(relativePath);
        if (!dir.exists()) {
            return;
        }
        File[] children = dir.listFiles();
        if (children != null) {
            for (File child : children) {
                if (child.isDirectory()) {
                    deleteDirectoryRecursively(child.toPath());
                } else {
                    child.delete();
                }
            }
        }
        dir.delete();
    }

    private void deleteDirectoryRecursively(Path path) {
        File file = path.toFile();
        File[] children = file.listFiles();
        if (children != null) {
            for (File child : children) {
                if (child.isDirectory()) {
                    deleteDirectoryRecursively(child.toPath());
                } else {
                    child.delete();
                }
            }
        }
        file.delete();
    }

    private String replacePathPrefix(String source, String oldPrefix, String newPrefix) {
        String normalizedSource = normalizeRelativePath(source);
        String normalizedOld = normalizeRelativePath(oldPrefix);
        String normalizedNew = normalizeRelativePath(newPrefix);
        if (Objects.equals(normalizedSource, normalizedOld)) {
            return normalizedNew;
        }
        if (normalizedSource.startsWith(normalizedOld + "/")) {
            return normalizedNew + normalizedSource.substring(normalizedOld.length());
        }
        return normalizedSource;
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }

    private String detectMimeType(Path path, String filename) {
        try {
            String mimeType = Files.probeContentType(path);
            if (hasText(mimeType)) {
                return mimeType;
            }
        } catch (IOException ignored) {}

        String ext = getExtension(filename).toLowerCase();
        return switch (ext) {
            case "pdf" -> "application/pdf";
            case "doc" -> "application/msword";
            case "docx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
            case "xls" -> "application/vnd.ms-excel";
            case "xlsx" -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
            case "ppt" -> "application/vnd.ms-powerpoint";
            case "pptx" -> "application/vnd.openxmlformats-officedocument.presentationml.presentation";
            case "jpg", "jpeg" -> "image/jpeg";
            case "png" -> "image/png";
            case "gif" -> "image/gif";
            case "webp" -> "image/webp";
            case "txt", "log" -> "text/plain";
            case "md" -> "text/markdown";
            case "json" -> "application/json";
            case "csv" -> "text/csv";
            case "mp4" -> "video/mp4";
            case "mp3" -> "audio/mpeg";
            default -> null;
        };
    }

    private String normalizeNullableText(String value) {
        return hasText(value) ? value.trim() : null;
    }

    private Map<String, Object> toFileItemPayload(UserFile file) {
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("id", file.getId());
        item.put("userId", file.getUserId());
        item.put("parentId", file.getParentId());
        item.put("name", file.getName());
        item.put("type", file.getType());
        item.put("filePath", file.getFilePath());
        item.put("fileSize", file.getFileSize());
        item.put("mimeType", file.getMimeType());
        item.put("createdAt", file.getCreatedAt() != null ? file.getCreatedAt().toString() : null);
        item.put("readOnly", file.getReadOnly());
        item.put("shared", file.getShared());
        item.put("grantRootId", file.getGrantRootId());
        item.put("sharedOwner", file.getSharedOwner());
        item.put("isFolder", TYPE_FOLDER.equals(file.getType()));
        return item;
    }

    private String safeLowerName(String value) {
        return value == null ? "" : value.toLowerCase();
    }

    private static class ScanStats {
        private int foldersCreated;
        private int foldersUpdated;
        private int filesCreated;
        private int filesUpdated;
        private int foldersDeleted;
        private int filesDeleted;
        private int unchanged;
        private int conflicts;
    }
}

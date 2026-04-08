package com.metrology.service;

import com.github.sardine.DavResource;
import com.github.sardine.Sardine;
import com.github.sardine.SardineFactory;
import com.metrology.entity.WebDavMount;
import com.metrology.repository.WebDavMountRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.io.InputStream;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.*;

@Service
@RequiredArgsConstructor
public class WebDavService {

    private final WebDavMountRepository mountRepository;

    public List<WebDavMount> listMounts(String userId) {
        return mountRepository.findByUserIdOrderByCreatedAtDesc(userId);
    }

    public WebDavMount saveMount(String userId, Map<String, String> body) {
        WebDavMount mount = new WebDavMount();
        mount.setUserId(userId);
        mount.setName(body.get("name"));
        mount.setUrl(normalizeUrl(body.get("url")));
        mount.setUsername(body.getOrDefault("username", ""));
        mount.setPassword(body.getOrDefault("password", ""));
        return mountRepository.save(mount);
    }

    public WebDavMount updateMount(String userId, Long id, Map<String, String> body) {
        WebDavMount mount = mountRepository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new IllegalArgumentException("挂载点不存在"));
        if (body.containsKey("name")) mount.setName(body.get("name"));
        if (body.containsKey("url")) mount.setUrl(normalizeUrl(body.get("url")));
        if (body.containsKey("username")) mount.setUsername(body.get("username"));
        if (body.containsKey("password") && !body.get("password").isEmpty()) {
            mount.setPassword(body.get("password"));
        }
        return mountRepository.save(mount);
    }

    public void deleteMount(String userId, Long id) {
        WebDavMount mount = mountRepository.findByIdAndUserId(id, userId)
                .orElseThrow(() -> new IllegalArgumentException("挂载点不存在"));
        mountRepository.delete(mount);
    }

    public boolean testConnection(String url, String username, String password) {
        try {
            Sardine sardine = buildSardine(username, password);
            sardine.list(normalizeUrl(url));
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    public List<Map<String, Object>> listFiles(String userId, Long mountId, String path) throws Exception {
        WebDavMount mount = mountRepository.findByIdAndUserId(mountId, userId)
                .orElseThrow(() -> new IllegalArgumentException("挂载点不存在"));
        Sardine sardine = buildSardine(mount.getUsername(), mount.getPassword());
        String baseUrl = mount.getUrl();
        String fullPath = path == null || path.isBlank() ? baseUrl : joinUrl(baseUrl, path);
        List<DavResource> resources = sardine.list(fullPath);
        List<Map<String, Object>> result = new ArrayList<>();
        for (int i = 0; i < resources.size(); i++) {
            DavResource r = resources.get(i);
            // Skip the root entry (first item is usually the directory itself)
            if (i == 0 && r.isDirectory()) continue;
            Map<String, Object> item = new HashMap<>();
            item.put("name", r.getName());
            item.put("path", r.getPath());
            item.put("isDirectory", r.isDirectory());
            item.put("size", r.getContentLength());
            item.put("contentType", r.getContentType());
            item.put("modified", r.getModified() != null ? r.getModified().getTime() : null);
            result.add(item);
        }
        // Sort: directories first, then files
        result.sort((a, b) -> {
            boolean aDir = (boolean) a.get("isDirectory");
            boolean bDir = (boolean) b.get("isDirectory");
            if (aDir != bDir) return aDir ? -1 : 1;
            return ((String) a.get("name")).compareToIgnoreCase((String) b.get("name"));
        });
        return result;
    }

    public InputStream downloadFileStream(String userId, Long mountId, String path) throws Exception {
        WebDavMount mount = mountRepository.findByIdAndUserId(mountId, userId)
                .orElseThrow(() -> new IllegalArgumentException("挂载点不存在"));
        Sardine sardine = buildSardine(mount.getUsername(), mount.getPassword());
        String fullUrl = path.startsWith("http") ? path : joinUrl(mount.getUrl(), path);
        return sardine.get(fullUrl);
    }

    public void uploadFile(String userId, Long mountId, String path, InputStream dataStream, String contentType) throws Exception {
        WebDavMount mount = mountRepository.findByIdAndUserId(mountId, userId)
                .orElseThrow(() -> new IllegalArgumentException("挂载点不存在"));
        Sardine sardine = buildSardine(mount.getUsername(), mount.getPassword());
        String fullUrl = path.startsWith("http") ? path : joinUrl(mount.getUrl(), path);
        putStream(sardine, fullUrl, dataStream, contentType != null ? contentType : "application/octet-stream");
    }

    private void putStream(Sardine sardine, String fullUrl, InputStream dataStream, String contentType) throws Exception {
        try {
            Method putWithType = Sardine.class.getMethod("put", String.class, InputStream.class, String.class);
            putWithType.invoke(sardine, fullUrl, dataStream, contentType);
            return;
        } catch (NoSuchMethodException ignored) {
            // Fallback to 2-arg stream API.
        } catch (InvocationTargetException ite) {
            throw unwrapInvocationException(ite);
        }

        try {
            Method putStream = Sardine.class.getMethod("put", String.class, InputStream.class);
            putStream.invoke(sardine, fullUrl, dataStream);
            return;
        } catch (NoSuchMethodException ignored) {
            // Fallback to byte[] API if stream API is unavailable.
        } catch (InvocationTargetException ite) {
            throw unwrapInvocationException(ite);
        }

        try {
            byte[] bytes = dataStream.readAllBytes();
            sardine.put(fullUrl, bytes, contentType);
        } catch (Exception e) {
            throw e;
        }
    }

    private Exception unwrapInvocationException(InvocationTargetException ite) {
        Throwable cause = ite.getTargetException();
        if (cause instanceof Exception exception) {
            return exception;
        }
        return new RuntimeException(cause);
    }

    private Sardine buildSardine(String username, String password) {
        if (username == null || username.isBlank()) {
            return SardineFactory.begin();
        }
        return SardineFactory.begin(username, password);
    }

    private String normalizeUrl(String url) {
        if (url == null) return "";
        url = url.trim();
        return url.endsWith("/") ? url : url + "/";
    }

    private String joinUrl(String base, String path) {
        if (!base.endsWith("/")) base = base + "/";
        if (path.startsWith("/")) path = path.substring(1);
        return base + path;
    }
}

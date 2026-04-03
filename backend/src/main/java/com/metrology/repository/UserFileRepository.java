package com.metrology.repository;

import com.metrology.entity.UserFile;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface UserFileRepository extends JpaRepository<UserFile, Long> {

    List<UserFile> findByUserIdAndParentIdOrderByTypeAscNameAsc(String userId, Long parentId);

    List<UserFile> findByUserIdAndNameContainingIgnoreCaseOrderByTypeAscNameAsc(String userId, String name);

    List<UserFile> findByNameContainingIgnoreCaseOrderByTypeAscNameAsc(String name);

    List<UserFile> findByParentId(Long parentId);

    List<UserFile> findByParentIdOrderByTypeAscNameAsc(Long parentId);

    boolean existsByUserIdAndParentIdAndName(String userId, Long parentId, String name);

    boolean existsByShareToken(String shareToken);

    boolean existsByShareTokenAndIdNot(String shareToken, Long id);

    Optional<UserFile> findByShareTokenAndTypeAndShareEnabledTrue(String shareToken, String type);
}

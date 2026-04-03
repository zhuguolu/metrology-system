package com.metrology.repository;

import com.metrology.entity.UserPermission;
import jakarta.transaction.Transactional;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface UserPermissionRepository extends JpaRepository<UserPermission, Long> {
    List<UserPermission> findByUserId(Long userId);

    @Transactional
    void deleteByUserId(Long userId);

    boolean existsByUserIdAndPermission(Long userId, String permission);
}

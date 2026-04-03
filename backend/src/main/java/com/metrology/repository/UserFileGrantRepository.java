package com.metrology.repository;

import com.metrology.entity.UserFileGrant;
import jakarta.transaction.Transactional;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface UserFileGrantRepository extends JpaRepository<UserFileGrant, Long> {

    List<UserFileGrant> findByUserId(Long userId);

    boolean existsByUserIdAndFolderId(Long userId, Long folderId);

    @Transactional
    void deleteByUserId(Long userId);
}

package com.metrology.repository;

import com.metrology.entity.WebDavMount;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;

public interface WebDavMountRepository extends JpaRepository<WebDavMount, Long> {
    List<WebDavMount> findByUserIdOrderByCreatedAtDesc(String userId);
    Optional<WebDavMount> findByIdAndUserId(Long id, String userId);
}

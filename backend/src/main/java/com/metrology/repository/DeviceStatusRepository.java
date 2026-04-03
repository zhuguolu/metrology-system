package com.metrology.repository;

import com.metrology.entity.DeviceStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface DeviceStatusRepository extends JpaRepository<DeviceStatus, Long> {
    List<DeviceStatus> findAllByOrderBySortOrderAsc();
    boolean existsByName(String name);
}

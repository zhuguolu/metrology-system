package com.metrology.service;

import com.metrology.entity.DeviceStatus;
import com.metrology.repository.DeviceStatusRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class DeviceStatusService {

    private final DeviceStatusRepository statusRepository;

    public List<DeviceStatus> getAll() {
        return statusRepository.findAllByOrderBySortOrderAsc();
    }

    public DeviceStatus create(String name) {
        if (name == null || name.isBlank()) throw new IllegalArgumentException("名称不能为空");
        if (statusRepository.existsByName(name.trim())) throw new IllegalArgumentException("状态名称已存在");
        DeviceStatus s = new DeviceStatus();
        s.setName(name.trim());
        s.setSortOrder((int) statusRepository.count());
        return statusRepository.save(s);
    }

    public DeviceStatus update(Long id, String name) {
        if (name == null || name.isBlank()) throw new IllegalArgumentException("名称不能为空");
        DeviceStatus s = statusRepository.findById(id).orElseThrow();
        s.setName(name.trim());
        return statusRepository.save(s);
    }

    public void delete(Long id) {
        statusRepository.deleteById(id);
    }
}

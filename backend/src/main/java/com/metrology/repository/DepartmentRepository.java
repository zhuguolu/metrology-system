package com.metrology.repository;

import com.metrology.entity.Department;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface DepartmentRepository extends JpaRepository<Department, Long> {
    List<Department> findAllByOrderBySortOrderAscNameAsc();
    Optional<Department> findByName(String name);
    boolean existsByName(String name);
    boolean existsByNameAndIdNot(String name, Long id);
    List<Department> findByParentIdIsNullOrderBySortOrderAscNameAsc();
    List<Department> findByParentIdOrderBySortOrderAscNameAsc(Long parentId);
}

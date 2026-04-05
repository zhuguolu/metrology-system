package com.metrology.repository;

import com.metrology.entity.Device;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;

public interface DeviceRepository extends JpaRepository<Device, Long> {

    @Query("SELECT d FROM Device d WHERE " +
           "(:search IS NULL OR d.name LIKE %:search% OR d.metricNo LIKE %:search% OR d.responsiblePerson LIKE %:search% OR d.assetNo LIKE %:search% OR d.serialNo LIKE %:search%) AND " +
           "(:assetNo IS NULL OR d.assetNo LIKE %:assetNo%) AND " +
           "(:serialNo IS NULL OR d.serialNo LIKE %:serialNo%) AND " +
           "(:dept IS NULL OR d.dept = :dept) AND " +
           "(:validity IS NULL OR d.validity = :validity) AND " +
           "(:useStatus IS NULL OR (:useStatus = '\u5176\u4ed6' AND (d.useStatus IS NULL OR TRIM(d.useStatus) = '' OR d.useStatus NOT IN ('\u6b63\u5e38', '\u6545\u969c', '\u62a5\u5e9f'))) OR (:useStatus <> '\u5176\u4ed6' AND d.useStatus = :useStatus))")
    List<Device> findWithFilters(@Param("search") String search,
                                  @Param("assetNo") String assetNo,
                                  @Param("serialNo") String serialNo,
                                  @Param("dept") String dept,
                                  @Param("validity") String validity,
                                  @Param("useStatus") String useStatus);

    @Query(
            value = "SELECT d FROM Device d WHERE " +
                    "(:search IS NULL OR d.name LIKE %:search% OR d.metricNo LIKE %:search% OR d.responsiblePerson LIKE %:search% OR d.assetNo LIKE %:search% OR d.serialNo LIKE %:search%) AND " +
                    "(:assetNo IS NULL OR d.assetNo LIKE %:assetNo%) AND " +
                    "(:serialNo IS NULL OR d.serialNo LIKE %:serialNo%) AND " +
                    "(:deptsEmpty = true OR d.dept IN :deptScopes) AND " +
                    "(:validity IS NULL OR d.validity = :validity) AND " +
                    "(:responsiblePerson IS NULL OR d.responsiblePerson = :responsiblePerson) AND " +
                    "(:useStatus IS NULL OR (:useStatus = '\u5176\u4ed6' AND (d.useStatus IS NULL OR TRIM(d.useStatus) = '' OR d.useStatus NOT IN ('\u6b63\u5e38', '\u6545\u969c', '\u62a5\u5e9f'))) OR (:useStatus <> '\u5176\u4ed6' AND d.useStatus = :useStatus)) AND " +
                    "(:nextDateFrom IS NULL OR d.nextDate >= :nextDateFrom) AND " +
                    "(:nextDateTo IS NULL OR d.nextDate <= :nextDateTo) AND " +
                    "(:todoOnly = false OR (d.useStatus = '\u6b63\u5e38' AND d.validity IN ('\u5931\u6548', '\u5373\u5c06\u8fc7\u671f')))",
            countQuery = "SELECT COUNT(d) FROM Device d WHERE " +
                    "(:search IS NULL OR d.name LIKE %:search% OR d.metricNo LIKE %:search% OR d.responsiblePerson LIKE %:search% OR d.assetNo LIKE %:search% OR d.serialNo LIKE %:search%) AND " +
                    "(:assetNo IS NULL OR d.assetNo LIKE %:assetNo%) AND " +
                    "(:serialNo IS NULL OR d.serialNo LIKE %:serialNo%) AND " +
                    "(:deptsEmpty = true OR d.dept IN :deptScopes) AND " +
                    "(:validity IS NULL OR d.validity = :validity) AND " +
                    "(:responsiblePerson IS NULL OR d.responsiblePerson = :responsiblePerson) AND " +
                    "(:useStatus IS NULL OR (:useStatus = '\u5176\u4ed6' AND (d.useStatus IS NULL OR TRIM(d.useStatus) = '' OR d.useStatus NOT IN ('\u6b63\u5e38', '\u6545\u969c', '\u62a5\u5e9f'))) OR (:useStatus <> '\u5176\u4ed6' AND d.useStatus = :useStatus)) AND " +
                    "(:nextDateFrom IS NULL OR d.nextDate >= :nextDateFrom) AND " +
                    "(:nextDateTo IS NULL OR d.nextDate <= :nextDateTo) AND " +
                    "(:todoOnly = false OR (d.useStatus = '\u6b63\u5e38' AND d.validity IN ('\u5931\u6548', '\u5373\u5c06\u8fc7\u671f')))"
    )
    Page<Device> findWithFiltersPaged(@Param("search") String search,
                                      @Param("assetNo") String assetNo,
                                      @Param("serialNo") String serialNo,
                                      @Param("deptScopes") List<String> deptScopes,
                                      @Param("deptsEmpty") boolean deptsEmpty,
                                      @Param("validity") String validity,
                                      @Param("responsiblePerson") String responsiblePerson,
                                      @Param("useStatus") String useStatus,
                                      @Param("nextDateFrom") LocalDate nextDateFrom,
                                      @Param("nextDateTo") LocalDate nextDateTo,
                                      @Param("todoOnly") boolean todoOnly,
                                      Pageable pageable);

    @Query("SELECT d.validity, COUNT(d) FROM Device d WHERE " +
            "(:search IS NULL OR d.name LIKE %:search% OR d.metricNo LIKE %:search% OR d.responsiblePerson LIKE %:search% OR d.assetNo LIKE %:search% OR d.serialNo LIKE %:search%) AND " +
            "(:assetNo IS NULL OR d.assetNo LIKE %:assetNo%) AND " +
            "(:serialNo IS NULL OR d.serialNo LIKE %:serialNo%) AND " +
            "(:deptsEmpty = true OR d.dept IN :deptScopes) AND " +
            "(:validity IS NULL OR d.validity = :validity) AND " +
            "(:responsiblePerson IS NULL OR d.responsiblePerson = :responsiblePerson) AND " +
            "(:useStatus IS NULL OR (:useStatus = '\u5176\u4ed6' AND (d.useStatus IS NULL OR TRIM(d.useStatus) = '' OR d.useStatus NOT IN ('\u6b63\u5e38', '\u6545\u969c', '\u62a5\u5e9f'))) OR (:useStatus <> '\u5176\u4ed6' AND d.useStatus = :useStatus)) AND " +
            "(:nextDateFrom IS NULL OR d.nextDate >= :nextDateFrom) AND " +
            "(:nextDateTo IS NULL OR d.nextDate <= :nextDateTo) AND " +
            "(:todoOnly = false OR (d.useStatus = '\u6b63\u5e38' AND d.validity IN ('\u5931\u6548', '\u5373\u5c06\u8fc7\u671f'))) " +
            "GROUP BY d.validity")
    List<Object[]> countValiditySummary(@Param("search") String search,
                                        @Param("assetNo") String assetNo,
                                        @Param("serialNo") String serialNo,
                                        @Param("deptScopes") List<String> deptScopes,
                                        @Param("deptsEmpty") boolean deptsEmpty,
                                        @Param("validity") String validity,
                                        @Param("responsiblePerson") String responsiblePerson,
                                        @Param("useStatus") String useStatus,
                                        @Param("nextDateFrom") LocalDate nextDateFrom,
                                        @Param("nextDateTo") LocalDate nextDateTo,
                                        @Param("todoOnly") boolean todoOnly);

    @Query("SELECT d.useStatus, COUNT(d) FROM Device d WHERE " +
            "(:search IS NULL OR d.name LIKE %:search% OR d.metricNo LIKE %:search% OR d.responsiblePerson LIKE %:search% OR d.assetNo LIKE %:search% OR d.serialNo LIKE %:search%) AND " +
            "(:assetNo IS NULL OR d.assetNo LIKE %:assetNo%) AND " +
            "(:serialNo IS NULL OR d.serialNo LIKE %:serialNo%) AND " +
            "(:deptsEmpty = true OR d.dept IN :deptScopes) AND " +
            "(:validity IS NULL OR d.validity = :validity) AND " +
            "(:responsiblePerson IS NULL OR d.responsiblePerson = :responsiblePerson) AND " +
            "(:useStatus IS NULL OR (:useStatus = '\u5176\u4ed6' AND (d.useStatus IS NULL OR TRIM(d.useStatus) = '' OR d.useStatus NOT IN ('\u6b63\u5e38', '\u6545\u969c', '\u62a5\u5e9f'))) OR (:useStatus <> '\u5176\u4ed6' AND d.useStatus = :useStatus)) AND " +
            "(:nextDateFrom IS NULL OR d.nextDate >= :nextDateFrom) AND " +
            "(:nextDateTo IS NULL OR d.nextDate <= :nextDateTo) AND " +
            "(:todoOnly = false OR (d.useStatus = '\u6b63\u5e38' AND d.validity IN ('\u5931\u6548', '\u5373\u5c06\u8fc7\u671f'))) " +
            "GROUP BY d.useStatus")
    List<Object[]> countUseStatusSummary(@Param("search") String search,
                                         @Param("assetNo") String assetNo,
                                         @Param("serialNo") String serialNo,
                                         @Param("deptScopes") List<String> deptScopes,
                                         @Param("deptsEmpty") boolean deptsEmpty,
                                         @Param("validity") String validity,
                                         @Param("responsiblePerson") String responsiblePerson,
                                         @Param("useStatus") String useStatus,
                                         @Param("nextDateFrom") LocalDate nextDateFrom,
                                         @Param("nextDateTo") LocalDate nextDateTo,
                                         @Param("todoOnly") boolean todoOnly);

    @Query("SELECT COUNT(d) FROM Device d WHERE " +
            "(:search IS NULL OR d.name LIKE %:search% OR d.metricNo LIKE %:search% OR d.responsiblePerson LIKE %:search% OR d.assetNo LIKE %:search% OR d.serialNo LIKE %:search%) AND " +
            "(:assetNo IS NULL OR d.assetNo LIKE %:assetNo%) AND " +
            "(:serialNo IS NULL OR d.serialNo LIKE %:serialNo%) AND " +
            "(:deptsEmpty = true OR d.dept IN :deptScopes) AND " +
            "(:validity IS NULL OR d.validity = :validity) AND " +
            "(:responsiblePerson IS NULL OR d.responsiblePerson = :responsiblePerson) AND " +
            "(:useStatus IS NULL OR (:useStatus = '\u5176\u4ed6' AND (d.useStatus IS NULL OR TRIM(d.useStatus) = '' OR d.useStatus NOT IN ('\u6b63\u5e38', '\u6545\u969c', '\u62a5\u5e9f'))) OR (:useStatus <> '\u5176\u4ed6' AND d.useStatus = :useStatus)) AND " +
            "(:nextDateFrom IS NULL OR d.nextDate >= :nextDateFrom) AND " +
            "(:nextDateTo IS NULL OR d.nextDate <= :nextDateTo) AND " +
            "(:todoOnly = false OR (d.useStatus = '\u6b63\u5e38' AND d.validity IN ('\u5931\u6548', '\u5373\u5c06\u8fc7\u671f')))")
    long countWithFilters(@Param("search") String search,
                          @Param("assetNo") String assetNo,
                          @Param("serialNo") String serialNo,
                          @Param("deptScopes") List<String> deptScopes,
                          @Param("deptsEmpty") boolean deptsEmpty,
                          @Param("validity") String validity,
                          @Param("responsiblePerson") String responsiblePerson,
                          @Param("useStatus") String useStatus,
                          @Param("nextDateFrom") LocalDate nextDateFrom,
                          @Param("nextDateTo") LocalDate nextDateTo,
                          @Param("todoOnly") boolean todoOnly);

    @Query("SELECT COUNT(d) FROM Device d WHERE d.nextDate >= :startDate AND d.nextDate <= :endDate")
    long countByNextDateBetween(@Param("startDate") LocalDate startDate, @Param("endDate") LocalDate endDate);

    @Query("SELECT YEAR(d.calDate) as yr, MONTH(d.calDate) as mo, COUNT(d) as cnt " +
           "FROM Device d WHERE d.calDate >= :since GROUP BY YEAR(d.calDate), MONTH(d.calDate) ORDER BY yr, mo")
    List<Object[]> countByCalDateMonth(@Param("since") LocalDate since);

    @Query("SELECT YEAR(d.calDate) as yr, MONTH(d.calDate) as mo, COUNT(d) as cnt " +
           "FROM Device d WHERE d.calDate >= :since AND d.dept = :dept " +
           "GROUP BY YEAR(d.calDate), MONTH(d.calDate) ORDER BY yr, mo")
    List<Object[]> countByCalDateMonthAndDept(@Param("since") LocalDate since, @Param("dept") String dept);
}

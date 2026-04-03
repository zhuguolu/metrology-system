package com.metrology.dto;

import lombok.AllArgsConstructor;
import lombok.Data;

import java.util.Collections;
import java.util.List;
import java.util.Map;

@Data
@AllArgsConstructor
public class PageResult<T> {
    private List<T> content;
    private long totalElements;
    private int totalPages;
    private int page;
    private int size;
    private Map<String, Long> summaryCounts;
    private Map<String, Long> useStatusSummary;

    public PageResult(List<T> content, long totalElements, int totalPages, int page, int size) {
        this(content, totalElements, totalPages, page, size, Collections.emptyMap(), Collections.emptyMap());
    }

    public PageResult(List<T> content, long totalElements, int totalPages, int page, int size,
                      Map<String, Long> summaryCounts) {
        this(content, totalElements, totalPages, page, size, summaryCounts, Collections.emptyMap());
    }
}

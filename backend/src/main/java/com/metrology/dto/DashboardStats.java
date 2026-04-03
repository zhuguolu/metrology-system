package com.metrology.dto;

import lombok.Data;
import java.util.List;
import java.util.Map;

@Data
public class DashboardStats {
    private long total;
    private long dueThisMonth;
    private long expired;
    private long warning;
    private long valid;
    private List<Map<String, Object>> monthlyTrend;
    private List<Map<String, Object>> deptStats;   // 按部门统计
}

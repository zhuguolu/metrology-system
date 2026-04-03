package com.metrology.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;
import java.util.Map;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class LoginResponse {
    private String token;
    private String username;
    private Long userId;
    private String role;
    private List<String> permissions;
    private String department;
    private List<String> departments;
    private List<Map<String, Object>> fileReadonlyFolders;
}

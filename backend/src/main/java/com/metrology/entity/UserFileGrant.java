package com.metrology.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "user_file_grants",
       uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "folder_id"}))
@Data
@NoArgsConstructor
@AllArgsConstructor
public class UserFileGrant {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "folder_id", nullable = false)
    private Long folderId;
}

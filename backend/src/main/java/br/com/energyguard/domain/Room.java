package br.com.energyguard.domain;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "rooms")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Room {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false, unique = true)
    private String name;

    private String location;

    private Integer capacity;

    @Column(name = "device_id", unique = true)
    private String deviceId;

    @Enumerated(EnumType.STRING)
    @Column(name = "occupancy_status", nullable = false)
    @Builder.Default
    private RoomOccupancyStatus occupancyStatus = RoomOccupancyStatus.EMPTY;

    @Column(name = "ac_status", nullable = false)
    @Builder.Default
    private Boolean acStatus = false;

    @Column(name = "target_temperature")
    @Builder.Default
    private Double targetTemperature = 23.0;

    @Column(name = "current_temperature")
    private Double currentTemperature;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    public void prePersist() {
        LocalDateTime now = LocalDateTime.now();
        this.createdAt = now;
        this.updatedAt = now;
        if (this.occupancyStatus == null) {
            this.occupancyStatus = RoomOccupancyStatus.EMPTY;
        }
        if (this.acStatus == null) {
            this.acStatus = false;
        }
        if (this.targetTemperature == null) {
            this.targetTemperature = 23.0;
        }
    }

    @PreUpdate
    public void preUpdate() {
        this.updatedAt = LocalDateTime.now();
    }
}

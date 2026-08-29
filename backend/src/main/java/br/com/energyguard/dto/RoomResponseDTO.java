package br.com.energyguard.dto;

import br.com.energyguard.domain.RoomOccupancyStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RoomResponseDTO {

    private UUID id;
    private String name;
    private String location;
    private Integer capacity;
    private String deviceId;
    private RoomOccupancyStatus occupancyStatus;
    private Boolean acStatus;
    private Double targetTemperature;
    private Double currentTemperature;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}

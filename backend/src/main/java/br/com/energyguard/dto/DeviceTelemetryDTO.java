package br.com.energyguard.dto;

import br.com.energyguard.domain.RoomOccupancyStatus;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DeviceTelemetryDTO {

    @NotBlank(message = "O identificador do dispositivo (deviceId) é obrigatório")
    private String deviceId;

    private RoomOccupancyStatus occupancyStatus;

    private Boolean acStatus;

    private Double currentTemperature;

    private Double targetTemperature;

    private Boolean wasteDetected;
}

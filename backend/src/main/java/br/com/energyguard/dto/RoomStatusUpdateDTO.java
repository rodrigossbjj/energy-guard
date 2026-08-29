package br.com.energyguard.dto;

import br.com.energyguard.domain.RoomOccupancyStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RoomStatusUpdateDTO {

    private RoomOccupancyStatus occupancyStatus;

    private Boolean acStatus;

    private Double currentTemperature;

    private Double targetTemperature;
}

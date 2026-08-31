package br.com.energyguard.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TelemetryResponseDTO {

    private RoomResponseDTO room;

    private boolean energyWasteDetected;

    private String message;
}

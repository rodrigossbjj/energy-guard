package br.com.energyguard.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DashboardSummaryDTO {

    private long totalRooms;
    private long roomsOccupied;
    private long roomsEmpty;
    private long roomsInAlert;
    private long acOnCount;
    private long wastingAcCount;
    private double estimatedWastedKwhPerHour;
    private double estimatedCostPerHour;
    private List<RoomResponseDTO> alertRooms;
}

package br.com.energyguard.service;

import br.com.energyguard.domain.Room;
import br.com.energyguard.domain.RoomOccupancyStatus;
import br.com.energyguard.dto.DashboardSummaryDTO;
import br.com.energyguard.dto.RoomResponseDTO;
import br.com.energyguard.repository.RoomRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;

@Service
@RequiredArgsConstructor
public class DashboardService {

    private final RoomRepository roomRepository;

    // Constantes médias para cálculo energético
    private static final double KW_PER_AC_UNIT = 1.5; // Média de consumo de um AC em kW
    private static final double ENERGY_TARIFF_BRL = 0.85; // Custo médio por kWh em R$

    @Transactional(readOnly = true)
    public DashboardSummaryDTO getDashboardSummary() {
        List<Room> allRooms = roomRepository.findAll();

        long totalRooms = allRooms.size();
        long roomsOccupied = allRooms.stream()
                .filter(r -> r.getOccupancyStatus() == RoomOccupancyStatus.OCCUPIED)
                .count();

        long roomsInAlert = allRooms.stream()
                .filter(r -> r.getOccupancyStatus() == RoomOccupancyStatus.ALERT_DESPERDICIO)
                .count();

        long roomsEmpty = totalRooms - roomsOccupied - roomsInAlert;

        long acOnCount = allRooms.stream()
                .filter(r -> Boolean.TRUE.equals(r.getAcStatus()))
                .count();

        // Salas desperdiçando energia: AC ligado e sala sem ocupação (EMPTY ou ALERT_DESPERDICIO)
        long wastingAcCount = allRooms.stream()
                .filter(r -> Boolean.TRUE.equals(r.getAcStatus()) && r.getOccupancyStatus() != RoomOccupancyStatus.OCCUPIED)
                .count();

        double rawWastedKwh = wastingAcCount * KW_PER_AC_UNIT;
        double rawCostBrl = rawWastedKwh * ENERGY_TARIFF_BRL;

        double estimatedWastedKwhPerHour = BigDecimal.valueOf(rawWastedKwh)
                .setScale(2, RoundingMode.HALF_UP)
                .doubleValue();

        double estimatedCostPerHour = BigDecimal.valueOf(rawCostBrl)
                .setScale(2, RoundingMode.HALF_UP)
                .doubleValue();

        List<RoomResponseDTO> alertRooms = allRooms.stream()
                .filter(r -> r.getOccupancyStatus() == RoomOccupancyStatus.ALERT_DESPERDICIO)
                .map(this::toRoomResponseDTO)
                .toList();

        return DashboardSummaryDTO.builder()
                .totalRooms(totalRooms)
                .roomsOccupied(roomsOccupied)
                .roomsEmpty(roomsEmpty)
                .roomsInAlert(roomsInAlert)
                .acOnCount(acOnCount)
                .wastingAcCount(wastingAcCount)
                .estimatedWastedKwhPerHour(estimatedWastedKwhPerHour)
                .estimatedCostPerHour(estimatedCostPerHour)
                .alertRooms(alertRooms)
                .build();
    }

    private RoomResponseDTO toRoomResponseDTO(Room room) {
        return RoomResponseDTO.builder()
                .id(room.getId())
                .name(room.getName())
                .location(room.getLocation())
                .capacity(room.getCapacity())
                .deviceId(room.getDeviceId())
                .occupancyStatus(room.getOccupancyStatus())
                .acStatus(room.getAcStatus())
                .targetTemperature(room.getTargetTemperature())
                .currentTemperature(room.getCurrentTemperature())
                .createdAt(room.getCreatedAt())
                .updatedAt(room.getUpdatedAt())
                .build();
    }
}

package br.com.energyguard.service;

import br.com.energyguard.domain.Room;
import br.com.energyguard.domain.RoomOccupancyStatus;
import br.com.energyguard.dto.DeviceTelemetryDTO;
import br.com.energyguard.dto.RoomResponseDTO;
import br.com.energyguard.dto.TelemetryResponseDTO;
import br.com.energyguard.exception.ResourceNotFoundException;
import br.com.energyguard.repository.RoomRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class TelemetryService {

    private final RoomRepository roomRepository;

    @Transactional
    public TelemetryResponseDTO processTelemetry(DeviceTelemetryDTO dto) {
        Room room = roomRepository.findByDeviceId(dto.getDeviceId())
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Nenhuma sala encontrada para o dispositivo com ID: " + dto.getDeviceId()));

        if (dto.getAcStatus() != null) {
            room.setAcStatus(dto.getAcStatus());
        }

        if (dto.getCurrentTemperature() != null) {
            room.setCurrentTemperature(dto.getCurrentTemperature());
        }

        if (dto.getTargetTemperature() != null) {
            room.setTargetTemperature(dto.getTargetTemperature());
        }

        boolean isWasteExplicit = Boolean.TRUE.equals(dto.getWasteDetected());
        RoomOccupancyStatus reportedStatus = dto.getOccupancyStatus();

        if (isWasteExplicit || reportedStatus == RoomOccupancyStatus.ALERT_DESPERDICIO) {
            room.setOccupancyStatus(RoomOccupancyStatus.ALERT_DESPERDICIO);
        } else if (reportedStatus != null) {
            if (reportedStatus == RoomOccupancyStatus.EMPTY && Boolean.TRUE.equals(room.getAcStatus())) {
                room.setOccupancyStatus(RoomOccupancyStatus.ALERT_DESPERDICIO);
            } else {
                room.setOccupancyStatus(reportedStatus);
            }
        } else {
            if (room.getOccupancyStatus() == RoomOccupancyStatus.EMPTY && Boolean.TRUE.equals(room.getAcStatus())) {
                room.setOccupancyStatus(RoomOccupancyStatus.ALERT_DESPERDICIO);
            }
        }

        Room updatedRoom = roomRepository.save(room);
        boolean energyWasteDetected = updatedRoom.getOccupancyStatus() == RoomOccupancyStatus.ALERT_DESPERDICIO;

        String message = energyWasteDetected
                ? "Alerta de desperdício de energia detectado para a sala " + updatedRoom.getName() + "!"
                : "Telemetria da sala " + updatedRoom.getName() + " atualizada com sucesso.";

        return TelemetryResponseDTO.builder()
                .room(toRoomResponseDTO(updatedRoom))
                .energyWasteDetected(energyWasteDetected)
                .message(message)
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

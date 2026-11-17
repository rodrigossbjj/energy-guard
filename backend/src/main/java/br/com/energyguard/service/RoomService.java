package br.com.energyguard.service;

import br.com.energyguard.domain.Room;
import br.com.energyguard.domain.RoomOccupancyStatus;
import br.com.energyguard.dto.AdminActionDTO;
import br.com.energyguard.dto.RoomCreateDTO;
import br.com.energyguard.dto.RoomResponseDTO;
import br.com.energyguard.dto.RoomStatusUpdateDTO;
import br.com.energyguard.dto.RoomUpdateDTO;
import br.com.energyguard.exception.BusinessException;
import br.com.energyguard.exception.ResourceNotFoundException;
import br.com.energyguard.repository.RoomRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class RoomService {

    private final RoomRepository roomRepository;

    @Value("${energyguard.portability.password:admin123}")
    private String portabilityPassword = "admin123";

    @Transactional
    public RoomResponseDTO createRoom(RoomCreateDTO dto) {
        if (roomRepository.existsByName(dto.getName())) {
            throw new BusinessException("Já existe uma sala cadastrada com o nome: " + dto.getName());
        }

        if (dto.getDeviceId() != null && !dto.getDeviceId().isBlank()) {
            Optional<Room> existingRoomOpt = roomRepository.findByDeviceId(dto.getDeviceId());
            if (existingRoomOpt.isPresent()) {
                Room existingRoom = existingRoomOpt.get();
                if (dto.getPortabilityPassword() == null || dto.getPortabilityPassword().isBlank()) {
                    throw new BusinessException("PORTABILITY_REQUIRED: O dispositivo '" + dto.getDeviceId() +
                            "' já está vinculado à sala '" + existingRoom.getName() +
                            "'. Digite a senha administrativa para autorizar a portabilidade.");
                }
                if (!portabilityPassword.equals(dto.getPortabilityPassword().trim())) {
                    throw new BusinessException("Senha de portabilidade incorreta.");
                }
                // Desvincula o dispositivo da sala anterior para garantir a unicidade
                existingRoom.setDeviceId(null);
                roomRepository.save(existingRoom);
            }
        }

        Room room = Room.builder()
                .name(dto.getName())
                .deviceId(dto.getDeviceId())
                .targetTemperature(dto.getTargetTemperature() != null ? dto.getTargetTemperature() : 23.0)
                .occupancyStatus(RoomOccupancyStatus.EMPTY)
                .acStatus(false)
                .build();

        Room savedRoom = roomRepository.save(room);
        return toDTO(savedRoom);
    }

    @Transactional(readOnly = true)
    public List<RoomResponseDTO> getAllRooms() {
        return roomRepository.findAll().stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public RoomResponseDTO getRoomById(UUID id) {
        Room room = findRoomEntityById(id);
        return toDTO(room);
    }

    @Transactional
    public RoomResponseDTO updateRoom(UUID id, RoomUpdateDTO dto) {
        Room room = findRoomEntityById(id);

        if (roomRepository.existsByNameAndIdNot(dto.getName(), id)) {
            throw new BusinessException("Já existe outra sala com o nome: " + dto.getName());
        }

        if (dto.getDeviceId() != null && !dto.getDeviceId().isBlank()) {
            Optional<Room> existingRoomOpt = roomRepository.findByDeviceId(dto.getDeviceId());
            if (existingRoomOpt.isPresent() && !existingRoomOpt.get().getId().equals(id)) {
                Room existingRoom = existingRoomOpt.get();
                if (dto.getPortabilityPassword() == null || dto.getPortabilityPassword().isBlank()) {
                    throw new BusinessException("PORTABILITY_REQUIRED: O dispositivo '" + dto.getDeviceId() +
                            "' já está vinculado à sala '" + existingRoom.getName() +
                            "'. Digite a senha administrativa para autorizar a portabilidade.");
                }
                if (!portabilityPassword.equals(dto.getPortabilityPassword().trim())) {
                    throw new BusinessException("Senha de portabilidade incorreta.");
                }
                // Desvincula o dispositivo da sala anterior para garantir a unicidade
                existingRoom.setDeviceId(null);
                roomRepository.save(existingRoom);
            }
        }

        room.setName(dto.getName());
        room.setDeviceId(dto.getDeviceId());
        if (dto.getTargetTemperature() != null) {
            room.setTargetTemperature(dto.getTargetTemperature());
        }

        Room updatedRoom = roomRepository.save(room);
        return toDTO(updatedRoom);
    }

    @Transactional
    public void deleteRoom(UUID id) {
        Room room = findRoomEntityById(id);
        roomRepository.delete(room);
    }

    @Transactional
    public RoomResponseDTO updateRoomStatus(UUID id, RoomStatusUpdateDTO dto) {
        Room room = findRoomEntityById(id);

        if (dto.getOccupancyStatus() != null) {
            room.setOccupancyStatus(dto.getOccupancyStatus());
        }
        if (dto.getAcStatus() != null) {
            room.setAcStatus(dto.getAcStatus());
        }
        if (dto.getTargetTemperature() != null) {
            room.setTargetTemperature(dto.getTargetTemperature());
        }

        Room updatedRoom = roomRepository.save(room);
        return toDTO(updatedRoom);
    }

    @Transactional
    public RoomResponseDTO unlinkDevice(UUID id, AdminActionDTO dto) {
        validateAdminPassword(dto != null ? dto.getAdminPassword() : null);
        Room room = findRoomEntityById(id);
        room.setDeviceId(null);
        room.setOccupancyStatus(RoomOccupancyStatus.EMPTY);
        room.setAcStatus(false);
        return toDTO(roomRepository.save(room));
    }

    @Transactional
    public RoomResponseDTO resetRoomMetrics(UUID id, AdminActionDTO dto) {
        validateAdminPassword(dto != null ? dto.getAdminPassword() : null);
        Room room = findRoomEntityById(id);
        room.setTotalWastedMinutes(0.0);
        room.setLastAbsenceMinutes(0.0);
        return toDTO(roomRepository.save(room));
    }

    @Transactional
    public void resetAllMetrics(AdminActionDTO dto) {
        validateAdminPassword(dto != null ? dto.getAdminPassword() : null);
        List<Room> rooms = roomRepository.findAll();
        for (Room room : rooms) {
            room.setTotalWastedMinutes(0.0);
            room.setLastAbsenceMinutes(0.0);
        }
        roomRepository.saveAll(rooms);
    }

    @Transactional
    public List<RoomResponseDTO> updateBatchTargetTemperature(AdminActionDTO dto) {
        validateAdminPassword(dto != null ? dto.getAdminPassword() : null);
        if (dto == null || dto.getTargetTemperature() == null || dto.getTargetTemperature() < 10 || dto.getTargetTemperature() > 40) {
            throw new BusinessException("Informe uma temperatura de referência válida entre 10°C e 40°C.");
        }
        List<Room> rooms = roomRepository.findAll();
        for (Room room : rooms) {
            room.setTargetTemperature(dto.getTargetTemperature());
        }
        return roomRepository.saveAll(rooms).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    private void validateAdminPassword(String password) {
        if (password == null || password.isBlank() || !portabilityPassword.equals(password.trim())) {
            throw new BusinessException("Senha administrativa inválida.");
        }
    }

    private Room findRoomEntityById(UUID id) {
        return roomRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Sala não encontrada com o ID: " + id));
    }

    private RoomResponseDTO toDTO(Room room) {
        return RoomResponseDTO.builder()
                .id(room.getId())
                .name(room.getName())
                .deviceId(room.getDeviceId())
                .occupancyStatus(room.getOccupancyStatus())
                .acStatus(room.getAcStatus())
                .targetTemperature(room.getTargetTemperature())
                .lastAbsenceMinutes(room.getLastAbsenceMinutes())
                .totalWastedMinutes(room.getTotalWastedMinutes())
                .createdAt(room.getCreatedAt())
                .updatedAt(room.getUpdatedAt())
                .build();
    }
}

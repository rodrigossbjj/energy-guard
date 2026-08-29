package br.com.energyguard.service;

import br.com.energyguard.domain.Room;
import br.com.energyguard.domain.RoomOccupancyStatus;
import br.com.energyguard.dto.RoomCreateDTO;
import br.com.energyguard.dto.RoomResponseDTO;
import br.com.energyguard.dto.RoomStatusUpdateDTO;
import br.com.energyguard.dto.RoomUpdateDTO;
import br.com.energyguard.exception.BusinessException;
import br.com.energyguard.exception.ResourceNotFoundException;
import br.com.energyguard.repository.RoomRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class RoomService {

    private final RoomRepository roomRepository;

    @Transactional
    public RoomResponseDTO createRoom(RoomCreateDTO dto) {
        if (roomRepository.existsByName(dto.getName())) {
            throw new BusinessException("Já existe uma sala cadastrada com o nome: " + dto.getName());
        }

        if (dto.getDeviceId() != null && !dto.getDeviceId().isBlank()) {
            if (roomRepository.existsByDeviceId(dto.getDeviceId())) {
                throw new BusinessException("Já existe uma sala associada ao dispositivo: " + dto.getDeviceId());
            }
        }

        Room room = Room.builder()
                .name(dto.getName())
                .location(dto.getLocation())
                .capacity(dto.getCapacity())
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
            if (roomRepository.existsByDeviceIdAndIdNot(dto.getDeviceId(), id)) {
                throw new BusinessException("Já existe outra sala associada ao dispositivo: " + dto.getDeviceId());
            }
        }

        room.setName(dto.getName());
        room.setLocation(dto.getLocation());
        room.setCapacity(dto.getCapacity());
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
        if (dto.getCurrentTemperature() != null) {
            room.setCurrentTemperature(dto.getCurrentTemperature());
        }
        if (dto.getTargetTemperature() != null) {
            room.setTargetTemperature(dto.getTargetTemperature());
        }

        Room updatedRoom = roomRepository.save(room);
        return toDTO(updatedRoom);
    }

    private Room findRoomEntityById(UUID id) {
        return roomRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Sala não encontrada com o ID: " + id));
    }

    private RoomResponseDTO toDTO(Room room) {
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

package br.com.energyguard.controller;

import br.com.energyguard.dto.AdminActionDTO;
import br.com.energyguard.dto.RoomCreateDTO;
import br.com.energyguard.dto.RoomResponseDTO;
import br.com.energyguard.dto.RoomStatusUpdateDTO;
import br.com.energyguard.dto.RoomUpdateDTO;
import br.com.energyguard.service.RoomService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/rooms")
@RequiredArgsConstructor
public class RoomController {

    private final RoomService roomService;

    @PostMapping
    public ResponseEntity<RoomResponseDTO> createRoom(@Valid @RequestBody RoomCreateDTO dto) {
        RoomResponseDTO created = roomService.createRoom(dto);
        return ResponseEntity.status(HttpStatus.CREATED).body(created);
    }

    @GetMapping
    public ResponseEntity<List<RoomResponseDTO>> getAllRooms() {
        return ResponseEntity.ok(roomService.getAllRooms());
    }

    @GetMapping("/{id}")
    public ResponseEntity<RoomResponseDTO> getRoomById(@PathVariable UUID id) {
        return ResponseEntity.ok(roomService.getRoomById(id));
    }

    @PutMapping("/{id}")
    public ResponseEntity<RoomResponseDTO> updateRoom(
            @PathVariable UUID id,
            @Valid @RequestBody RoomUpdateDTO dto
    ) {
        return ResponseEntity.ok(roomService.updateRoom(id, dto));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteRoom(@PathVariable UUID id) {
        roomService.deleteRoom(id);
        return ResponseEntity.noContent().build();
    }

    @PatchMapping("/{id}/status")
    public ResponseEntity<RoomResponseDTO> updateRoomStatus(
            @PathVariable UUID id,
            @RequestBody RoomStatusUpdateDTO dto
    ) {
        return ResponseEntity.ok(roomService.updateRoomStatus(id, dto));
    }

    @PostMapping("/{id}/unlink-device")
    public ResponseEntity<RoomResponseDTO> unlinkDevice(
            @PathVariable UUID id,
            @RequestBody AdminActionDTO dto
    ) {
        return ResponseEntity.ok(roomService.unlinkDevice(id, dto));
    }

    @PostMapping("/{id}/reset-metrics")
    public ResponseEntity<RoomResponseDTO> resetRoomMetrics(
            @PathVariable UUID id,
            @RequestBody AdminActionDTO dto
    ) {
        return ResponseEntity.ok(roomService.resetRoomMetrics(id, dto));
    }

    @PostMapping("/reset-metrics")
    public ResponseEntity<Void> resetAllMetrics(@RequestBody AdminActionDTO dto) {
        roomService.resetAllMetrics(dto);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/batch-temperature")
    public ResponseEntity<List<RoomResponseDTO>> updateBatchTargetTemperature(@RequestBody AdminActionDTO dto) {
        return ResponseEntity.ok(roomService.updateBatchTargetTemperature(dto));
    }
}

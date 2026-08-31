package br.com.energyguard.service;

import br.com.energyguard.domain.Room;
import br.com.energyguard.domain.RoomOccupancyStatus;
import br.com.energyguard.dto.DeviceTelemetryDTO;
import br.com.energyguard.dto.TelemetryResponseDTO;
import br.com.energyguard.exception.ResourceNotFoundException;
import br.com.energyguard.repository.RoomRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class TelemetryServiceTest {

    @Mock
    private RoomRepository roomRepository;

    @InjectMocks
    private TelemetryService telemetryService;

    private Room room;
    private String deviceId;

    @BeforeEach
    void setUp() {
        deviceId = "ESP32-101";
        room = Room.builder()
                .id(UUID.randomUUID())
                .name("Sala de Reuniões")
                .location("Bloco C")
                .capacity(10)
                .deviceId(deviceId)
                .occupancyStatus(RoomOccupancyStatus.EMPTY)
                .acStatus(false)
                .targetTemperature(23.0)
                .currentTemperature(26.0)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();
    }

    @Test
    @DisplayName("Deve detectar desperdício de energia quando a sala estiver vazia e o AC for ligado")
    void processTelemetry_DetectsEnergyWaste_WhenEmptyAndAcOn() {
        DeviceTelemetryDTO dto = DeviceTelemetryDTO.builder()
                .deviceId(deviceId)
                .occupancyStatus(RoomOccupancyStatus.EMPTY)
                .acStatus(true)
                .currentTemperature(25.0)
                .build();

        when(roomRepository.findByDeviceId(deviceId)).thenReturn(Optional.of(room));
        when(roomRepository.save(any(Room.class))).thenAnswer(invocation -> invocation.getArgument(0));

        TelemetryResponseDTO response = telemetryService.processTelemetry(dto);

        assertThat(response).isNotNull();
        assertThat(response.isEnergyWasteDetected()).isTrue();
        assertThat(response.getRoom().getOccupancyStatus()).isEqualTo(RoomOccupancyStatus.ALERT_DESPERDICIO);
        assertThat(response.getRoom().getAcStatus()).isTrue();
        assertThat(response.getMessage()).contains("Alerta de desperdício de energia detectado");
        verify(roomRepository, times(1)).save(room);
    }

    @Test
    @DisplayName("Deve registrar status OCCUPIED sem alerta quando a sala estiver ocupada e com AC ligado")
    void processTelemetry_NormalOccupiedState() {
        DeviceTelemetryDTO dto = DeviceTelemetryDTO.builder()
                .deviceId(deviceId)
                .occupancyStatus(RoomOccupancyStatus.OCCUPIED)
                .acStatus(true)
                .currentTemperature(22.0)
                .build();

        when(roomRepository.findByDeviceId(deviceId)).thenReturn(Optional.of(room));
        when(roomRepository.save(any(Room.class))).thenAnswer(invocation -> invocation.getArgument(0));

        TelemetryResponseDTO response = telemetryService.processTelemetry(dto);

        assertThat(response).isNotNull();
        assertThat(response.isEnergyWasteDetected()).isFalse();
        assertThat(response.getRoom().getOccupancyStatus()).isEqualTo(RoomOccupancyStatus.OCCUPIED);
        assertThat(response.getRoom().getAcStatus()).isTrue();
        verify(roomRepository, times(1)).save(room);
    }

    @Test
    @DisplayName("Deve lançar ResourceNotFoundException para dispositivo não cadastrado")
    void processTelemetry_UnknownDeviceId_ThrowsException() {
        DeviceTelemetryDTO dto = DeviceTelemetryDTO.builder()
                .deviceId("ESP32-UNKNOWN")
                .build();

        when(roomRepository.findByDeviceId("ESP32-UNKNOWN")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> telemetryService.processTelemetry(dto))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Nenhuma sala encontrada para o dispositivo com ID: ESP32-UNKNOWN");

        verify(roomRepository, never()).save(any());
    }
}

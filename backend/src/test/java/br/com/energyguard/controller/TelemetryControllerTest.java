package br.com.energyguard.controller;

import br.com.energyguard.config.KeycloakProperties;
import br.com.energyguard.config.SecurityConfig;
import br.com.energyguard.domain.RoomOccupancyStatus;
import br.com.energyguard.dto.DeviceTelemetryDTO;
import br.com.energyguard.dto.RoomResponseDTO;
import br.com.energyguard.dto.TelemetryResponseDTO;
import br.com.energyguard.exception.ResourceNotFoundException;
import br.com.energyguard.service.TelemetryService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(TelemetryController.class)
@Import({SecurityConfig.class, KeycloakProperties.class})
class TelemetryControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private TelemetryService telemetryService;

    @Test
    @DisplayName("Deve permitir requisição sem token JWT (pública para microcontroladores) e processar telemetria com sucesso")
    void receiveTelemetry_PublicAccess_Success() throws Exception {
        DeviceTelemetryDTO dto = DeviceTelemetryDTO.builder()
                .deviceId("ESP32-101")
                .acStatus(true)
                .occupancyStatus(RoomOccupancyStatus.EMPTY)
                .currentTemperature(24.5)
                .build();

        RoomResponseDTO roomDTO = RoomResponseDTO.builder()
                .id(UUID.randomUUID())
                .name("Sala 101")
                .deviceId("ESP32-101")
                .acStatus(true)
                .occupancyStatus(RoomOccupancyStatus.ALERT_DESPERDICIO)
                .currentTemperature(24.5)
                .build();

        TelemetryResponseDTO responseDTO = TelemetryResponseDTO.builder()
                .room(roomDTO)
                .energyWasteDetected(true)
                .message("Alerta de desperdício de energia detectado para a sala Sala 101!")
                .build();

        when(telemetryService.processTelemetry(any(DeviceTelemetryDTO.class))).thenReturn(responseDTO);

        mockMvc.perform(post("/api/v1/telemetry")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(dto)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.energyWasteDetected").value(true))
                .andExpect(jsonPath("$.room.occupancyStatus").value("ALERT_DESPERDICIO"))
                .andExpect(jsonPath("$.message").value("Alerta de desperdício de energia detectado para a sala Sala 101!"));
    }

    @Test
    @DisplayName("Deve retornar 400 Bad Request ao enviar telemetria sem deviceId")
    void receiveTelemetry_MissingDeviceId_BadRequest() throws Exception {
        DeviceTelemetryDTO dto = DeviceTelemetryDTO.builder()
                .acStatus(true)
                .build();

        mockMvc.perform(post("/api/v1/telemetry")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(dto)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400));
    }

    @Test
    @DisplayName("Deve retornar 404 Not Found para dispositivo não registrado")
    void receiveTelemetry_DeviceNotFound_NotFound() throws Exception {
        DeviceTelemetryDTO dto = DeviceTelemetryDTO.builder()
                .deviceId("ESP32-999")
                .build();

        when(telemetryService.processTelemetry(any(DeviceTelemetryDTO.class)))
                .thenThrow(new ResourceNotFoundException("Nenhuma sala encontrada para o dispositivo com ID: ESP32-999"));

        mockMvc.perform(post("/api/v1/telemetry")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(dto)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }
}

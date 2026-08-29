package br.com.energyguard.controller;

import br.com.energyguard.config.KeycloakProperties;
import br.com.energyguard.config.SecurityConfig;
import br.com.energyguard.domain.RoomOccupancyStatus;
import br.com.energyguard.dto.RoomCreateDTO;
import br.com.energyguard.dto.RoomResponseDTO;
import br.com.energyguard.dto.RoomStatusUpdateDTO;
import br.com.energyguard.dto.RoomUpdateDTO;
import br.com.energyguard.exception.BusinessException;
import br.com.energyguard.exception.ResourceNotFoundException;
import br.com.energyguard.service.RoomService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(RoomController.class)
@Import({SecurityConfig.class, KeycloakProperties.class})
class RoomControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private RoomService roomService;

    @Test
    @DisplayName("Deve retornar 401 Unauthorized ao acessar GET /api/v1/rooms sem token JWT")
    void shouldReturn401WhenAccessingWithoutToken() throws Exception {
        mockMvc.perform(get("/api/v1/rooms"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("Deve criar sala com sucesso quando autenticado")
    void shouldCreateRoomWhenAuthenticated() throws Exception {
        UUID id = UUID.randomUUID();
        RoomCreateDTO createDTO = RoomCreateDTO.builder()
                .name("Sala 101")
                .location("Bloco A")
                .capacity(30)
                .deviceId("ESP32-101")
                .build();

        RoomResponseDTO responseDTO = RoomResponseDTO.builder()
                .id(id)
                .name("Sala 101")
                .location("Bloco A")
                .capacity(30)
                .deviceId("ESP32-101")
                .occupancyStatus(RoomOccupancyStatus.EMPTY)
                .acStatus(false)
                .targetTemperature(23.0)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();

        when(roomService.createRoom(any(RoomCreateDTO.class))).thenReturn(responseDTO);

        mockMvc.perform(post("/api/v1/rooms")
                        .with(jwt().authorities(new SimpleGrantedAuthority("ROLE_USER")))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(createDTO)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(id.toString()))
                .andExpect(jsonPath("$.name").value("Sala 101"))
                .andExpect(jsonPath("$.capacity").value(30));
    }

    @Test
    @DisplayName("Deve retornar 400 Bad Request ao tentar criar sala sem nome")
    void shouldReturn400WhenNameIsBlank() throws Exception {
        RoomCreateDTO createDTO = RoomCreateDTO.builder()
                .name("")
                .capacity(10)
                .build();

        mockMvc.perform(post("/api/v1/rooms")
                        .with(jwt().authorities(new SimpleGrantedAuthority("ROLE_USER")))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(createDTO)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400));
    }

    @Test
    @DisplayName("Deve listar todas as salas cadastradas")
    void shouldGetAllRooms() throws Exception {
        UUID id = UUID.randomUUID();
        RoomResponseDTO responseDTO = RoomResponseDTO.builder()
                .id(id)
                .name("Sala 101")
                .occupancyStatus(RoomOccupancyStatus.EMPTY)
                .acStatus(false)
                .build();

        when(roomService.getAllRooms()).thenReturn(List.of(responseDTO));

        mockMvc.perform(get("/api/v1/rooms")
                        .with(jwt().authorities(new SimpleGrantedAuthority("ROLE_USER"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(id.toString()))
                .andExpect(jsonPath("$[0].name").value("Sala 101"));
    }

    @Test
    @DisplayName("Deve buscar sala por ID com sucesso")
    void shouldGetRoomById() throws Exception {
        UUID id = UUID.randomUUID();
        RoomResponseDTO responseDTO = RoomResponseDTO.builder()
                .id(id)
                .name("Sala 101")
                .build();

        when(roomService.getRoomById(id)).thenReturn(responseDTO);

        mockMvc.perform(get("/api/v1/rooms/{id}", id)
                        .with(jwt().authorities(new SimpleGrantedAuthority("ROLE_USER"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(id.toString()))
                .andExpect(jsonPath("$.name").value("Sala 101"));
    }

    @Test
    @DisplayName("Deve retornar 404 Not Found quando a sala não for encontrada")
    void shouldReturn404WhenRoomNotFound() throws Exception {
        UUID id = UUID.randomUUID();
        when(roomService.getRoomById(id)).thenThrow(new ResourceNotFoundException("Sala não encontrada com o ID: " + id));

        mockMvc.perform(get("/api/v1/rooms/{id}", id)
                        .with(jwt().authorities(new SimpleGrantedAuthority("ROLE_USER"))))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));
    }

    @Test
    @DisplayName("Deve atualizar dados da sala com sucesso")
    void shouldUpdateRoom() throws Exception {
        UUID id = UUID.randomUUID();
        RoomUpdateDTO updateDTO = RoomUpdateDTO.builder()
                .name("Sala 101 Modificada")
                .capacity(40)
                .build();

        RoomResponseDTO responseDTO = RoomResponseDTO.builder()
                .id(id)
                .name("Sala 101 Modificada")
                .capacity(40)
                .build();

        when(roomService.updateRoom(eq(id), any(RoomUpdateDTO.class))).thenReturn(responseDTO);

        mockMvc.perform(put("/api/v1/rooms/{id}", id)
                        .with(jwt().authorities(new SimpleGrantedAuthority("ROLE_USER")))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(updateDTO)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Sala 101 Modificada"))
                .andExpect(jsonPath("$.capacity").value(40));
    }

    @Test
    @DisplayName("Deve deletar sala com sucesso")
    void shouldDeleteRoom() throws Exception {
        UUID id = UUID.randomUUID();

        mockMvc.perform(delete("/api/v1/rooms/{id}", id)
                        .with(jwt().authorities(new SimpleGrantedAuthority("ROLE_USER"))))
                .andExpect(status().isNoContent());
    }

    @Test
    @DisplayName("Deve atualizar status da sala via PATCH")
    void shouldUpdateRoomStatus() throws Exception {
        UUID id = UUID.randomUUID();
        RoomStatusUpdateDTO statusDTO = RoomStatusUpdateDTO.builder()
                .acStatus(true)
                .occupancyStatus(RoomOccupancyStatus.OCCUPIED)
                .currentTemperature(22.0)
                .build();

        RoomResponseDTO responseDTO = RoomResponseDTO.builder()
                .id(id)
                .name("Sala 101")
                .acStatus(true)
                .occupancyStatus(RoomOccupancyStatus.OCCUPIED)
                .currentTemperature(22.0)
                .build();

        when(roomService.updateRoomStatus(eq(id), any(RoomStatusUpdateDTO.class))).thenReturn(responseDTO);

        mockMvc.perform(patch("/api/v1/rooms/{id}/status", id)
                        .with(jwt().authorities(new SimpleGrantedAuthority("ROLE_USER")))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(statusDTO)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.acStatus").value(true))
                .andExpect(jsonPath("$.occupancyStatus").value("OCCUPIED"))
                .andExpect(jsonPath("$.currentTemperature").value(22.0));
    }
}

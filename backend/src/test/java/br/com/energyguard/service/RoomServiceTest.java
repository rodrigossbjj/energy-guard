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
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class RoomServiceTest {

    @Mock
    private RoomRepository roomRepository;

    @InjectMocks
    private RoomService roomService;

    private Room room;
    private UUID roomId;

    @BeforeEach
    void setUp() {
        roomId = UUID.randomUUID();
        room = Room.builder()
                .id(roomId)
                .name("Lab 101")
                .deviceId("ESP32-001")
                .occupancyStatus(RoomOccupancyStatus.EMPTY)
                .acStatus(false)
                .targetTemperature(23.0)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();
    }

    @Test
    @DisplayName("Deve criar uma sala com sucesso quando os dados forem válidos")
    void createRoom_Success() {
        RoomCreateDTO createDTO = RoomCreateDTO.builder()
                .name("Lab 101")
                .deviceId("ESP32-001")
                .targetTemperature(22.0)
                .build();

        when(roomRepository.existsByName("Lab 101")).thenReturn(false);
        when(roomRepository.findByDeviceId("ESP32-001")).thenReturn(Optional.empty());
        when(roomRepository.save(any(Room.class))).thenReturn(room);

        RoomResponseDTO response = roomService.createRoom(createDTO);

        assertThat(response).isNotNull();
        assertThat(response.getId()).isEqualTo(roomId);
        assertThat(response.getName()).isEqualTo("Lab 101");
        verify(roomRepository, times(1)).save(any(Room.class));
    }

    @Test
    @DisplayName("Deve lançar BusinessException ao tentar criar sala com nome duplicado")
    void createRoom_DuplicateName_ThrowsException() {
        RoomCreateDTO createDTO = RoomCreateDTO.builder()
                .name("Lab 101")
                .build();

        when(roomRepository.existsByName("Lab 101")).thenReturn(true);

        assertThatThrownBy(() -> roomService.createRoom(createDTO))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("Já existe uma sala cadastrada com o nome: Lab 101");

        verify(roomRepository, never()).save(any(Room.class));
    }

    @Test
    @DisplayName("Deve retornar a lista de salas cadastradas")
    void getAllRooms_Success() {
        when(roomRepository.findAll()).thenReturn(List.of(room));

        List<RoomResponseDTO> rooms = roomService.getAllRooms();

        assertThat(rooms).hasSize(1);
        assertThat(rooms.get(0).getName()).isEqualTo("Lab 101");
    }

    @Test
    @DisplayName("Deve buscar sala por ID com sucesso")
    void getRoomById_Success() {
        when(roomRepository.findById(roomId)).thenReturn(Optional.of(room));

        RoomResponseDTO response = roomService.getRoomById(roomId);

        assertThat(response).isNotNull();
        assertThat(response.getId()).isEqualTo(roomId);
    }

    @Test
    @DisplayName("Deve lançar ResourceNotFoundException quando ID da sala não for encontrado")
    void getRoomById_NotFound_ThrowsException() {
        when(roomRepository.findById(roomId)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> roomService.getRoomById(roomId))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Sala não encontrada com o ID: " + roomId);
    }

    @Test
    @DisplayName("Deve atualizar dados da sala com sucesso")
    void updateRoom_Success() {
        RoomUpdateDTO updateDTO = RoomUpdateDTO.builder()
                .name("Lab 102 Atualizado")
                .deviceId("ESP32-002")
                .targetTemperature(21.0)
                .build();

        when(roomRepository.findById(roomId)).thenReturn(Optional.of(room));
        when(roomRepository.existsByNameAndIdNot("Lab 102 Atualizado", roomId)).thenReturn(false);
        when(roomRepository.findByDeviceId("ESP32-002")).thenReturn(Optional.empty());
        when(roomRepository.save(any(Room.class))).thenReturn(room);

        RoomResponseDTO response = roomService.updateRoom(roomId, updateDTO);

        assertThat(response).isNotNull();
        verify(roomRepository, times(1)).save(room);
    }

    @Test
    @DisplayName("Deve exigir senha de portabilidade ao criar sala com dispositivo já existente")
    void createRoom_DuplicateDevice_WithoutPassword_ThrowsPortabilityRequired() {
        Room existingRoom = Room.builder()
                .id(UUID.randomUUID())
                .name("Sala Antiga")
                .deviceId("ESP32-001")
                .build();

        RoomCreateDTO createDTO = RoomCreateDTO.builder()
                .name("Sala Nova")
                .deviceId("ESP32-001")
                .build();

        when(roomRepository.existsByName("Sala Nova")).thenReturn(false);
        when(roomRepository.findByDeviceId("ESP32-001")).thenReturn(Optional.of(existingRoom));

        assertThatThrownBy(() -> roomService.createRoom(createDTO))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("PORTABILITY_REQUIRED")
                .hasMessageContaining("Sala Antiga");

        verify(roomRepository, never()).save(any(Room.class));
    }

    @Test
    @DisplayName("Deve lançar erro ao informar senha de portabilidade incorreta")
    void createRoom_DuplicateDevice_WrongPassword_ThrowsException() {
        Room existingRoom = Room.builder()
                .id(UUID.randomUUID())
                .name("Sala Antiga")
                .deviceId("ESP32-001")
                .build();

        RoomCreateDTO createDTO = RoomCreateDTO.builder()
                .name("Sala Nova")
                .deviceId("ESP32-001")
                .portabilityPassword("senha_errada")
                .build();

        when(roomRepository.existsByName("Sala Nova")).thenReturn(false);
        when(roomRepository.findByDeviceId("ESP32-001")).thenReturn(Optional.of(existingRoom));

        assertThatThrownBy(() -> roomService.createRoom(createDTO))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("Senha de portabilidade incorreta");

        verify(roomRepository, never()).save(any(Room.class));
    }

    @Test
    @DisplayName("Deve autorizar portabilidade e desvincular dispositivo da sala anterior com senha correta")
    void createRoom_DuplicateDevice_CorrectPassword_TransfersDevice() {
        Room existingRoom = Room.builder()
                .id(UUID.randomUUID())
                .name("Sala Antiga")
                .deviceId("ESP32-001")
                .build();

        RoomCreateDTO createDTO = RoomCreateDTO.builder()
                .name("Sala Nova")
                .deviceId("ESP32-001")
                .portabilityPassword("admin123")
                .build();

        when(roomRepository.existsByName("Sala Nova")).thenReturn(false);
        when(roomRepository.findByDeviceId("ESP32-001")).thenReturn(Optional.of(existingRoom));
        when(roomRepository.save(any(Room.class))).thenReturn(room);

        RoomResponseDTO response = roomService.createRoom(createDTO);

        assertThat(response).isNotNull();
        // Verifica se a sala anterior foi desvinculada e ambas foram salvas
        assertThat(existingRoom.getDeviceId()).isNull();
        verify(roomRepository, times(1)).save(existingRoom);
        verify(roomRepository, times(2)).save(any(Room.class));
    }

    @Test
    @DisplayName("Deve remover sala com sucesso")
    void deleteRoom_Success() {
        when(roomRepository.findById(roomId)).thenReturn(Optional.of(room));

        roomService.deleteRoom(roomId);

        verify(roomRepository, times(1)).delete(room);
    }

    @Test
    @DisplayName("Deve atualizar o status em tempo real de uma sala com sucesso")
    void updateRoomStatus_Success() {
        RoomStatusUpdateDTO statusDTO = RoomStatusUpdateDTO.builder()
                .occupancyStatus(RoomOccupancyStatus.OCCUPIED)
                .acStatus(true)
                .build();

        when(roomRepository.findById(roomId)).thenReturn(Optional.of(room));
        when(roomRepository.save(any(Room.class))).thenReturn(room);

        RoomResponseDTO response = roomService.updateRoomStatus(roomId, statusDTO);

        assertThat(response).isNotNull();
        verify(roomRepository, times(1)).save(room);
    }
}

package br.com.energyguard.service;

import br.com.energyguard.domain.Room;
import br.com.energyguard.domain.RoomOccupancyStatus;
import br.com.energyguard.dto.DashboardSummaryDTO;
import br.com.energyguard.repository.RoomRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class DashboardServiceTest {

    @Mock
    private RoomRepository roomRepository;

    @InjectMocks
    private DashboardService dashboardService;

    @Test
    @DisplayName("Deve calcular corretamente os indicadores do dashboard quando houver salas cadastradas")
    void getDashboardSummary_Success() {
        Room room1 = Room.builder()
                .id(UUID.randomUUID())
                .name("Sala 1")
                .occupancyStatus(RoomOccupancyStatus.OCCUPIED)
                .acStatus(true)
                .build();

        Room room2 = Room.builder()
                .id(UUID.randomUUID())
                .name("Sala 2")
                .occupancyStatus(RoomOccupancyStatus.ALERT_DESPERDICIO)
                .acStatus(true)
                .build();

        Room room3 = Room.builder()
                .id(UUID.randomUUID())
                .name("Sala 3")
                .occupancyStatus(RoomOccupancyStatus.EMPTY)
                .acStatus(false)
                .build();

        when(roomRepository.findAll()).thenReturn(List.of(room1, room2, room3));

        DashboardSummaryDTO summary = dashboardService.getDashboardSummary();

        assertThat(summary).isNotNull();
        assertThat(summary.getTotalRooms()).isEqualTo(3);
        assertThat(summary.getRoomsOccupied()).isEqualTo(1);
        assertThat(summary.getRoomsInAlert()).isEqualTo(1);
        assertThat(summary.getRoomsEmpty()).isEqualTo(1);
        assertThat(summary.getAcOnCount()).isEqualTo(2);
        assertThat(summary.getWastingAcCount()).isEqualTo(1); // apenas room2 (ALERT_DESPERDICIO + AC LIGADO)
        assertThat(summary.getEstimatedWastedKwhPerHour()).isEqualTo(1.5); // 1 * 1.5
        assertThat(summary.getEstimatedCostPerHour()).isEqualTo(1.28); // 1.5 * 0.85 = 1.275 -> 1.28
        assertThat(summary.getAlertRooms()).hasSize(1);
        assertThat(summary.getAlertRooms().get(0).getName()).isEqualTo("Sala 2");
    }
}

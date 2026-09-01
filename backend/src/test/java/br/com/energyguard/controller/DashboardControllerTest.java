package br.com.energyguard.controller;

import br.com.energyguard.config.KeycloakProperties;
import br.com.energyguard.config.SecurityConfig;
import br.com.energyguard.dto.DashboardSummaryDTO;
import br.com.energyguard.service.DashboardService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Collections;

import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(DashboardController.class)
@Import({SecurityConfig.class, KeycloakProperties.class})
class DashboardControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private DashboardService dashboardService;

    @Test
    @DisplayName("Deve retornar 401 Unauthorized ao acessar GET /api/v1/dashboard/summary sem autenticação")
    void shouldReturn401WhenUnauthenticated() throws Exception {
        mockMvc.perform(get("/api/v1/dashboard/summary"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("Deve retornar o resumo do dashboard com sucesso quando autenticado")
    void getDashboardSummary_Success() throws Exception {
        DashboardSummaryDTO summary = DashboardSummaryDTO.builder()
                .totalRooms(5)
                .roomsOccupied(2)
                .roomsEmpty(2)
                .roomsInAlert(1)
                .acOnCount(3)
                .wastingAcCount(1)
                .estimatedWastedKwhPerHour(1.5)
                .estimatedCostPerHour(1.28)
                .alertRooms(Collections.emptyList())
                .build();

        when(dashboardService.getDashboardSummary()).thenReturn(summary);

        mockMvc.perform(get("/api/v1/dashboard/summary")
                        .with(jwt().authorities(new SimpleGrantedAuthority("ROLE_USER"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalRooms").value(5))
                .andExpect(jsonPath("$.roomsInAlert").value(1))
                .andExpect(jsonPath("$.wastingAcCount").value(1))
                .andExpect(jsonPath("$.estimatedCostPerHour").value(1.28));
    }
}

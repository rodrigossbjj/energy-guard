package br.com.energyguard.controller;

import br.com.energyguard.config.KeycloakProperties;
import br.com.energyguard.config.SecurityConfig;
import br.com.energyguard.dto.KeycloakConfigResponse;
import br.com.energyguard.dto.UserProfileResponse;
import br.com.energyguard.service.AuthService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(AuthController.class)
@Import({SecurityConfig.class, KeycloakProperties.class})
class AuthControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private AuthService authService;

    @Test
    @DisplayName("Deve retornar as configurações públicas do Keycloak sem autenticação")
    void shouldReturnKeycloakConfigWithoutAuth() throws Exception {
        KeycloakConfigResponse config = KeycloakConfigResponse.builder()
                .authServerUrl("http://localhost:8080")
                .realm("energy-guard")
                .clientId("energy-guard-app")
                .issuerUri("http://localhost:8080/realms/energy-guard")
                .loginUrl("http://localhost:8080/realms/energy-guard/protocol/openid-connect/auth?client_id=energy-guard-app&response_type=code&scope=openid%20profile%20email")
                .logoutUrl("http://localhost:8080/realms/energy-guard/protocol/openid-connect/logout?client_id=energy-guard-app")
                .build();

        when(authService.getKeycloakConfig()).thenReturn(config);

        mockMvc.perform(get("/api/v1/auth/config"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.realm").value("energy-guard"))
                .andExpect(jsonPath("$.clientId").value("energy-guard-app"));
    }

    @Test
    @DisplayName("Deve retornar 401 Unauthorized ao acessar /api/v1/auth/me sem token JWT")
    void shouldReturn401WhenAccessingMeWithoutToken() throws Exception {
        mockMvc.perform(get("/api/v1/auth/me"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("Deve retornar perfil do usuário logado quando autenticado via JWT")
    void shouldReturnUserProfileWhenAuthenticated() throws Exception {
        UserProfileResponse userProfile = UserProfileResponse.builder()
                .id("user-123")
                .username("rodrigo")
                .email("rodrigo@energyguard.com")
                .name("Rodrigo Sales")
                .roles(List.of("ROLE_USER"))
                .build();

        when(authService.getUserProfile(any(), any())).thenReturn(userProfile);

        mockMvc.perform(get("/api/v1/auth/me")
                        .with(jwt().jwt(builder -> builder.subject("user-123").claim("preferred_username", "rodrigo"))
                                .authorities(new SimpleGrantedAuthority("ROLE_USER"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value("user-123"))
                .andExpect(jsonPath("$.username").value("rodrigo"))
                .andExpect(jsonPath("$.email").value("rodrigo@energyguard.com"))
                .andExpect(jsonPath("$.roles[0]").value("ROLE_USER"));
    }
}

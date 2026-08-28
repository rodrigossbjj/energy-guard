package br.com.energyguard.controller;

import br.com.energyguard.dto.KeycloakConfigResponse;
import br.com.energyguard.dto.UserProfileResponse;
import br.com.energyguard.service.AuthService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @GetMapping("/config")
    public ResponseEntity<KeycloakConfigResponse> getConfig() {
        return ResponseEntity.ok(authService.getKeycloakConfig());
    }

    @GetMapping("/me")
    public ResponseEntity<UserProfileResponse> getCurrentUser(
            @AuthenticationPrincipal Jwt jwt,
            Authentication authentication
    ) {
        return ResponseEntity.ok(authService.getUserProfile(jwt, authentication));
    }

    @GetMapping("/logout-url")
    public ResponseEntity<Map<String, String>> getLogoutUrl() {
        return ResponseEntity.ok(Map.of("logoutUrl", authService.getLogoutUrl()));
    }
}

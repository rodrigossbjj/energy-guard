package br.com.energyguard.service;

import br.com.energyguard.config.KeycloakProperties;
import br.com.energyguard.dto.KeycloakConfigResponse;
import br.com.energyguard.dto.UserProfileResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final KeycloakProperties keycloakProperties;

    public KeycloakConfigResponse getKeycloakConfig() {
        return KeycloakConfigResponse.builder()
                .authServerUrl(keycloakProperties.getAuthServerUrl())
                .realm(keycloakProperties.getRealm())
                .clientId(keycloakProperties.getClientId())
                .issuerUri(keycloakProperties.getIssuerUri())
                .loginUrl(keycloakProperties.getLoginUrl())
                .logoutUrl(keycloakProperties.getLogoutUrl())
                .build();
    }

    public UserProfileResponse getUserProfile(Jwt jwt, Authentication authentication) {
        String id = jwt.getSubject();
        String username = jwt.getClaimAsString("preferred_username");
        if (username == null) {
            username = jwt.getClaimAsString("sub");
        }

        String email = jwt.getClaimAsString("email");

        String name = jwt.getClaimAsString("name");
        if (name == null) {
            String givenName = jwt.getClaimAsString("given_name");
            String familyName = jwt.getClaimAsString("family_name");
            if (givenName != null || familyName != null) {
                name = ((givenName != null ? givenName : "") + " " + (familyName != null ? familyName : "")).trim();
            } else {
                name = username;
            }
        }

        List<String> roles = authentication.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .collect(Collectors.toList());

        return UserProfileResponse.builder()
                .id(id)
                .username(username)
                .email(email)
                .name(name)
                .roles(roles)
                .build();
    }

    public String getLogoutUrl() {
        return keycloakProperties.getLogoutUrl();
    }
}

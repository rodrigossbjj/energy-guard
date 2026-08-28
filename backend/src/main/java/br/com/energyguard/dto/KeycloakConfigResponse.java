package br.com.energyguard.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class KeycloakConfigResponse {
    private String authServerUrl;
    private String realm;
    private String clientId;
    private String issuerUri;
    private String loginUrl;
    private String logoutUrl;
}

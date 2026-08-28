package br.com.energyguard.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Getter
@Setter
@Component
@ConfigurationProperties(prefix = "keycloak")
public class KeycloakProperties {

    private String authServerUrl = "http://localhost:8080";
    private String realm = "energy-guard";
    private String clientId = "energy-guard-app";
    private String clientSecret;

    public String getIssuerUri() {
        return normalizeUrl(authServerUrl) + "/realms/" + realm;
    }

    public String getLoginUrl() {
        return getIssuerUri() + "/protocol/openid-connect/auth?client_id=" + clientId
                + "&response_type=code&scope=openid%20profile%20email";
    }

    public String getLogoutUrl() {
        return getIssuerUri() + "/protocol/openid-connect/logout?client_id=" + clientId;
    }

    private String normalizeUrl(String url) {
        if (url != null && url.endsWith("/")) {
            return url.substring(0, url.length() - 1);
        }
        return url;
    }
}

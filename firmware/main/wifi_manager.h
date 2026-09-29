#ifndef WIFI_MANAGER_H
#define WIFI_MANAGER_H

#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

// Configurações padrão de Wi-Fi (podem ser alteradas via menuconfig)
#ifndef CONFIG_ESP_WIFI_SSID
#define CONFIG_ESP_WIFI_SSID "EnergyGuard_WiFi"
#endif

#ifndef CONFIG_ESP_WIFI_PASS
#define CONFIG_ESP_WIFI_PASS "12345678"
#endif

#ifndef CONFIG_ESP_MAXIMUM_RETRY
#define CONFIG_ESP_MAXIMUM_RETRY 5
#endif

/**
 * @brief Inicializa o NVS Flash, a stack de rede e estabelece a conexão Wi-Fi Station.
 * @return esp_err_t ESP_OK em caso de sucesso na conexão, ESP_FAIL em caso de falha.
 */
esp_err_t wifi_manager_init(void);

/**
 * @brief Verifica se o dispositivo está atualmente conectado ao AP Wi-Fi com IP atribuído.
 * @return true se conectado, false caso contrário.
 */
bool wifi_manager_is_connected(void);

/**
 * @brief Obtém a representação em texto do endereço IP atual.
 * @param buf Buffer de destino.
 * @param len Tamanho do buffer.
 */
void wifi_manager_get_ip_str(char *buf, size_t len);

#ifdef __cplusplus
}
#endif

#endif // WIFI_MANAGER_H

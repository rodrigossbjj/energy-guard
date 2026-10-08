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

#define WIFI_NVS_NAMESPACE "wifi_config"
#define WIFI_NVS_KEY_SSID  "ssid"
#define WIFI_NVS_KEY_PASS  "password"

/**
 * @brief Inicializa o NVS Flash, a stack de rede e tenta conectar usando dados salvos no NVS.
 * @return esp_err_t ESP_OK se conectado com sucesso, ESP_FAIL se não houver credenciais salvas ou falhar.
 */
esp_err_t wifi_manager_init(void);

/**
 * @brief Salva as credenciais Wi-Fi (SSID e Senha) na partição NVS Flash.
 */
esp_err_t wifi_manager_save_credentials(const char *ssid, const char *password);

/**
 * @brief Carrega as credenciais Wi-Fi armazenadas na NVS Flash.
 */
esp_err_t wifi_manager_load_credentials(char *ssid_out, size_t ssid_len, char *pass_out, size_t pass_len);

/**
 * @brief Limpa as credenciais Wi-Fi armazenadas na NVS Flash.
 */
esp_err_t wifi_manager_clear_credentials(void);

/**
 * @brief Tenta conectar ao AP Wi-Fi utilizando o SSID e Senha fornecidos dinamicamente.
 */
esp_err_t wifi_manager_connect_with_credentials(const char *ssid, const char *password);

/**
 * @brief Verifica se existem credenciais de Wi-Fi armazenadas na NVS.
 */
bool wifi_manager_has_stored_credentials(void);

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

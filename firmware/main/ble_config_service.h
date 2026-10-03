#ifndef BLE_CONFIG_SERVICE_H
#define BLE_CONFIG_SERVICE_H

#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Inicializa o serviço BLE com a stack NimBLE.
 *        Configura as callbacks do NimBLE sem necessariamente iniciar o anúncio.
 *
 * @return esp_err_t ESP_OK em caso de sucesso.
 */
esp_err_t ble_config_service_init(void);

/**
 * @brief Ativa o rádio BLE e inicia os anúncios (Advertising) utilizando
 *        o nome amigável derivado do dispositivo (ex: Energy Guard - EG-A4CF12).
 *
 * @return esp_err_t ESP_OK em caso de sucesso.
 */
esp_err_t ble_config_service_start(void);

/**
 * @brief Interrompe os anúncios e desativa a operação BLE sob demanda.
 *
 * @return esp_err_t ESP_OK em caso de sucesso.
 */
esp_err_t ble_config_service_stop(void);

/**
 * @brief Verifica se o serviço de configuração via BLE está ativo e anunciando.
 *
 * @return true Se o rádio BLE estiver ativo e anunciando.
 * @return false Se o BLE estiver desativado ou inativo.
 */
bool ble_config_service_is_active(void);

#ifdef __cplusplus
}
#endif

#endif // BLE_CONFIG_SERVICE_H

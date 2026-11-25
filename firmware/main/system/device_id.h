#ifndef DEVICE_ID_H
#define DEVICE_ID_H

#include <stddef.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Obtém o sufixo único do dispositivo baseado no MAC Wi-Fi STA (ex: "EG-A4CF12").
 * 
 * @param buf Buffer para armazenar a string resultante (tamanho recomendado: pelo menos 10 bytes).
 * @param len Tamanho do buffer.
 * @return esp_err_t ESP_OK em caso de sucesso.
 */
esp_err_t device_id_get_short(char *buf, size_t len);

/**
 * @brief Obtém o nome amigável para anúncio BLE (ex: "Energy Guard - EG-A4CF12").
 * 
 * @param buf Buffer para armazenar a string resultante (tamanho recomendado: pelo menos 32 bytes).
 * @param len Tamanho do buffer.
 * @return esp_err_t ESP_OK em caso de sucesso.
 */
esp_err_t device_id_get_ble_name(char *buf, size_t len);

/**
 * @brief Obtém a representação em texto do MAC address completo (ex: "AA:BB:CC:DD:EE:FF").
 * 
 * @param buf Buffer para armazenar a string (mínimo 18 bytes).
 * @param len Tamanho do buffer.
 * @return esp_err_t ESP_OK em caso de sucesso.
 */
esp_err_t device_id_get_mac_str(char *buf, size_t len);

#ifdef __cplusplus
}
#endif

#endif // DEVICE_ID_H

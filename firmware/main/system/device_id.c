#include "device_id.h"
#include <stdio.h>
#include <string.h>
#include "esp_mac.h"
#include "esp_log.h"

static const char *TAG = "DEVICE_ID";

esp_err_t device_id_get_mac_str(char *buf, size_t len)
{
    if (!buf || len < 18) {
        return ESP_ERR_INVALID_ARG;
    }
    uint8_t mac[6] = {0};
    esp_err_t ret = esp_read_mac(mac, ESP_MAC_WIFI_STA);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Falha ao ler endereço MAC da interface Wi-Fi STA");
        return ret;
    }
    snprintf(buf, len, "%02X:%02X:%02X:%02X:%02X:%02X",
             mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    return ESP_OK;
}

esp_err_t device_id_get_short(char *buf, size_t len)
{
    if (!buf || len < 10) {
        return ESP_ERR_INVALID_ARG;
    }
    uint8_t mac[6] = {0};
    esp_err_t ret = esp_read_mac(mac, ESP_MAC_WIFI_STA);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "Falha ao ler endereço MAC para ID curto");
        return ret;
    }
    snprintf(buf, len, "EG-%02X%02X%02X", mac[3], mac[4], mac[5]);
    return ESP_OK;
}

esp_err_t device_id_get_ble_name(char *buf, size_t len)
{
    if (!buf || len < 26) {
        return ESP_ERR_INVALID_ARG;
    }
    char short_id[16] = {0};
    esp_err_t ret = device_id_get_short(short_id, sizeof(short_id));
    if (ret != ESP_OK) {
        return ret;
    }
    snprintf(buf, len, "Energy Guard - %s", short_id);
    return ESP_OK;
}

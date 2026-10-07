#include "wifi_manager.h"

#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "nvs.h"
#include "lwip/err.h"
#include "lwip/sys.h"

static const char *TAG = "WIFI_MANAGER";

#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT      BIT1

static EventGroupHandle_t s_wifi_event_group = NULL;
static int s_retry_num = 0;
static char s_ip_addr_str[16] = "0.0.0.0";
static bool s_is_connected = false;
static bool s_stack_initialized = false;

static void event_handler(void* arg, esp_event_base_t event_base,
                            int32_t event_id, void* event_data)
{
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        ESP_LOGI(TAG, "Wi-Fi Station iniciado. Tentando conectar ao AP...");
        esp_wifi_connect();
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        s_is_connected = false;
        if (s_retry_num < CONFIG_ESP_MAXIMUM_RETRY) {
            s_retry_num++;
            ESP_LOGW(TAG, "Tentativa de reconexão ao AP (%d/%d)...", s_retry_num, CONFIG_ESP_MAXIMUM_RETRY);
            esp_wifi_connect();
        } else {
            xEventGroupSetBits(s_wifi_event_group, WIFI_FAIL_BIT);
            ESP_LOGE(TAG, "Falha ao conectar no AP Wi-Fi após %d tentativas.", CONFIG_ESP_MAXIMUM_RETRY);
        }
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t* event = (ip_event_got_ip_t*) event_data;
        snprintf(s_ip_addr_str, sizeof(s_ip_addr_str), IPSTR, IP2STR(&event->ip_info.ip));
        ESP_LOGI(TAG, "========================================");
        ESP_LOGI(TAG, "Wi-Fi CONECTADO COM SUCESSO!");
        ESP_LOGI(TAG, "Endereço IP: %s", s_ip_addr_str);
        ESP_LOGI(TAG, "========================================");
        s_retry_num = 0;
        s_is_connected = true;
        xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
    }
}

esp_err_t wifi_manager_save_credentials(const char *ssid, const char *password)
{
    if (!ssid) {
        return ESP_ERR_INVALID_ARG;
    }

    nvs_handle_t nvs_h;
    esp_err_t err = nvs_open(WIFI_NVS_NAMESPACE, NVS_READWRITE, &nvs_h);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Erro ao abrir NVS Flash para escrita: 0x%x", err);
        return err;
    }

    err = nvs_set_str(nvs_h, WIFI_NVS_KEY_SSID, ssid);
    if (err == ESP_OK) {
        err = nvs_set_str(nvs_h, WIFI_NVS_KEY_PASS, password ? password : "");
    }

    if (err == ESP_OK) {
        err = nvs_commit(nvs_h);
        ESP_LOGI(TAG, "Credenciais Wi-Fi salvas com sucesso no NVS (SSID: '%s')", ssid);
    } else {
        ESP_LOGE(TAG, "Erro ao gravar credenciais Wi-Fi no NVS: 0x%x", err);
    }

    nvs_close(nvs_h);
    return err;
}

esp_err_t wifi_manager_load_credentials(char *ssid_out, size_t ssid_len, char *pass_out, size_t pass_len)
{
    if (!ssid_out || ssid_len == 0) {
        return ESP_ERR_INVALID_ARG;
    }

    nvs_handle_t nvs_h;
    esp_err_t err = nvs_open(WIFI_NVS_NAMESPACE, NVS_READONLY, &nvs_h);
    if (err != ESP_OK) {
        return err;
    }

    err = nvs_get_str(nvs_h, WIFI_NVS_KEY_SSID, ssid_out, &ssid_len);
    if (err == ESP_OK && pass_out && pass_len > 0) {
        nvs_get_str(nvs_h, WIFI_NVS_KEY_PASS, pass_out, &pass_len);
    }

    nvs_close(nvs_h);
    return err;
}

esp_err_t wifi_manager_clear_credentials(void)
{
    nvs_handle_t nvs_h;
    esp_err_t err = nvs_open(WIFI_NVS_NAMESPACE, NVS_READWRITE, &nvs_h);
    if (err != ESP_OK) {
        return err;
    }

    err = nvs_erase_all(nvs_h);
    if (err == ESP_OK) {
        nvs_commit(nvs_h);
        ESP_LOGI(TAG, "Credenciais Wi-Fi apagadas do NVS Flash.");
    }

    nvs_close(nvs_h);
    return err;
}

bool wifi_manager_has_stored_credentials(void)
{
    char ssid[33] = {0};
    size_t len = sizeof(ssid);
    return (wifi_manager_load_credentials(ssid, len, NULL, 0) == ESP_OK && strlen(ssid) > 0);
}

esp_err_t wifi_manager_connect_with_credentials(const char *ssid, const char *password)
{
    if (!ssid || strlen(ssid) == 0) {
        return ESP_ERR_INVALID_ARG;
    }

    if (!s_stack_initialized) {
        ESP_LOGE(TAG, "Stack Wi-Fi não inicializada! Chame wifi_manager_init() primeiro.");
        return ESP_ERR_INVALID_STATE;
    }

    s_retry_num = 0;
    s_is_connected = false;
    xEventGroupClearBits(s_wifi_event_group, WIFI_CONNECTED_BIT | WIFI_FAIL_BIT);

    esp_wifi_stop();

    wifi_config_t wifi_config = {0};
    strncpy((char *)wifi_config.sta.ssid, ssid, sizeof(wifi_config.sta.ssid) - 1);
    if (password) {
        strncpy((char *)wifi_config.sta.password, password, sizeof(wifi_config.sta.password) - 1);
    }
    wifi_config.sta.threshold.authmode = (password && strlen(password) > 0) ? WIFI_AUTH_WPA2_PSK : WIFI_AUTH_OPEN;
    wifi_config.sta.pmf_cfg.capable = true;
    wifi_config.sta.pmf_cfg.required = false;

    ESP_LOGI(TAG, "Tentando conectar à rede Wi-Fi '%s'...", ssid);
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());

    // Limita a potência de transmissão de rádio para 10 dBm (40 em unidades de 0.25 dBm)
    esp_wifi_set_max_tx_power(40);
    ESP_ERROR_CHECK(esp_wifi_set_ps(WIFI_PS_MIN_MODEM));

    EventBits_t bits = xEventGroupWaitBits(s_wifi_event_group,
            WIFI_CONNECTED_BIT | WIFI_FAIL_BIT,
            pdFALSE,
            pdFALSE,
            pdMS_TO_TICKS(15000));

    if (bits & WIFI_CONNECTED_BIT) {
        wifi_manager_save_credentials(ssid, password);
        return ESP_OK;
    } else {
        ESP_LOGW(TAG, "Falha ao estabelecer conexão Wi-Fi com '%s'.", ssid);
        return ESP_FAIL;
    }
}

esp_err_t wifi_manager_init(void)
{
    if (s_stack_initialized) {
        return ESP_OK;
    }

    // Inicialização do NVS Flash
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    s_wifi_event_group = xEventGroupCreate();

    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    esp_event_handler_instance_t instance_any_id;
    esp_event_handler_instance_t instance_got_ip;
    ESP_ERROR_CHECK(esp_event_handler_instance_register(WIFI_EVENT,
                                                        ESP_EVENT_ANY_ID,
                                                        &event_handler,
                                                        NULL,
                                                        &instance_any_id));
    ESP_ERROR_CHECK(esp_event_handler_instance_register(IP_EVENT,
                                                        IP_EVENT_STA_GOT_IP,
                                                        &event_handler,
                                                        NULL,
                                                        &instance_got_ip));

    s_stack_initialized = true;

    char stored_ssid[33] = {0};
    char stored_pass[65] = {0};

    if (wifi_manager_has_stored_credentials()) {
        wifi_manager_load_credentials(stored_ssid, sizeof(stored_ssid), stored_pass, sizeof(stored_pass));
        ESP_LOGI(TAG, "Credenciais NVS encontradas! SSID: '%s'. Conectando...", stored_ssid);
        return wifi_manager_connect_with_credentials(stored_ssid, stored_pass);
    } else {
        ESP_LOGW(TAG, "Nenhuma credencial salva no NVS Flash. Operando em Modo Offline.");
        ESP_LOGW(TAG, "Pressione o botão no GPIO 34 para configurar o Wi-Fi via BLE.");
        return ESP_FAIL;
    }
}

bool wifi_manager_is_connected(void)
{
    return s_is_connected;
}

void wifi_manager_get_ip_str(char *buf, size_t len)
{
    if (buf && len > 0) {
        strncpy(buf, s_ip_addr_str, len - 1);
        buf[len - 1] = '\0';
    }
}

#include "ble_config_service.h"
#include <string.h>
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

/* NimBLE stack headers */
#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "host/ble_hs.h"
#include "host/util/util.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"

#include "device_id.h"

static const char *TAG = "BLE_CONFIG_SVC";

static bool s_ble_initialized = false;
static bool s_ble_active = false;
static uint8_t s_own_addr_type = BLE_OWN_ADDR_PUBLIC;

static void ble_config_start_advertising(void);

/**
 * @brief Handler de eventos GAP do NimBLE.
 */
static int ble_config_gap_event(struct ble_gap_event *event, void *arg)
{
    switch (event->type) {
    case BLE_GAP_EVENT_CONNECT:
        ESP_LOGI(TAG, "[BLE GAP] Conexão estabelecida: status=%d, handle=%d",
                 event->connect.status, event->connect.conn_handle);
        if (event->connect.status != 0) {
            /* Conexão falhou, reinicia anúncio se ativo */
            if (s_ble_active) {
                ble_config_start_advertising();
            }
        }
        break;

    case BLE_GAP_EVENT_DISCONNECT:
        ESP_LOGI(TAG, "[BLE GAP] Dispositivo desconectado: razão=%d", event->disconnect.reason);
        if (s_ble_active) {
            ble_config_start_advertising();
        }
        break;

    case BLE_GAP_EVENT_ADV_COMPLETE:
        ESP_LOGI(TAG, "[BLE GAP] Anúncio finalizado: razão=%d", event->adv_complete.reason);
        if (s_ble_active) {
            ble_config_start_advertising();
        }
        break;

    default:
        break;
    }

    return 0;
}

/**
 * @brief Configura e dispara os anúncios BLE GAP com o nome do dispositivo.
 */
static void ble_config_start_advertising(void)
{
    struct ble_hs_adv_fields fields;
    struct ble_gap_adv_params adv_params;
    int rc;

    memset(&fields, 0, sizeof(fields));

    /* Configuração dos flags padrão e potência de transmissão */
    fields.flags = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP;
    fields.tx_pwr_lvl_is_present = 1;
    fields.tx_pwr_lvl = BLE_HS_ADV_TX_PWR_LVL_AUTO;

    /* Nome dinâmico do dispositivo (Energy Guard - EG-XXXXXX) */
    char ble_name[32] = {0};
    device_id_get_ble_name(ble_name, sizeof(ble_name));

    fields.name = (uint8_t *)ble_name;
    fields.name_len = strlen(ble_name);
    fields.name_is_complete = 1;

    rc = ble_svc_gap_device_name_set(ble_name);
    if (rc != 0) {
        ESP_LOGE(TAG, "Erro ao definir nome GAP no NimBLE: rc=%d", rc);
    }

    rc = ble_gap_adv_set_fields(&fields);
    if (rc != 0) {
        ESP_LOGE(TAG, "Erro ao definir campos de anúncio BLE: rc=%d", rc);
        return;
    }

    /* Parâmetros de anúncios indiretos conectáveis */
    memset(&adv_params, 0, sizeof(adv_params));
    adv_params.conn_mode = BLE_GAP_CONN_MODE_UND;
    adv_params.disc_mode = BLE_GAP_DISC_MODE_GEN;

    rc = ble_gap_adv_start(s_own_addr_type, NULL, BLE_HS_FOREVER,
                           &adv_params, ble_config_gap_event, NULL);
    if (rc != 0) {
        ESP_LOGE(TAG, "Erro ao iniciar anúncio GAP: rc=%d", rc);
    } else {
        ESP_LOGI(TAG, "========================================");
        ESP_LOGI(TAG, ">>> ANÚNCIO BLE ATIVO: '%s' <<<", ble_name);
        ESP_LOGI(TAG, "========================================");
    }
}

/**
 * @brief Callback de sincronização do NimBLE Host com o Controller.
 */
static void ble_config_on_sync(void)
{
    int rc = ble_hs_util_ensure_addr(0);
    if (rc != 0) {
        ESP_LOGE(TAG, "Erro ao garantir endereço BLE: rc=%d", rc);
        return;
    }
    rc = ble_hs_id_infer_auto(0, &s_own_addr_type);
    if (rc != 0) {
        ESP_LOGE(TAG, "Erro ao inferir tipo de endereço próprio BLE: rc=%d", rc);
        return;
    }

    ESP_LOGI(TAG, "NimBLE Host sincronizado com sucesso! Tipo de endereço: %d", s_own_addr_type);

    if (s_ble_active) {
        ble_config_start_advertising();
    }
}

/**
 * @brief Callback de reset do NimBLE Host.
 */
static void ble_config_on_reset(int reason)
{
    ESP_LOGW(TAG, "NimBLE Host resetado. Razão: %d", reason);
}

/**
 * @brief Tarefa FreeRTOS executando o loop do NimBLE host.
 */
static void ble_config_host_task(void *param)
{
    ESP_LOGI(TAG, "Tarefa do NimBLE Host iniciada.");
    nimble_port_run();
    nimble_port_freertos_deinit();
}

esp_err_t ble_config_service_init(void)
{
    if (s_ble_initialized) {
        return ESP_OK;
    }

    int rc = nimble_port_init();
    if (rc != 0) {
        ESP_LOGE(TAG, "Falha ao inicializar NimBLE port: rc=%d", rc);
        return ESP_FAIL;
    }

    /* Inicialização dos serviços básicos do NimBLE */
    ble_svc_gap_init();
    ble_svc_gatt_init();

    /* Configuração das callbacks */
    ble_hs_cfg.reset_cb = ble_config_on_reset;
    ble_hs_cfg.sync_cb = ble_config_on_sync;

    /* Dispara a thread FreeRTOS para a stack NimBLE */
    nimble_port_freertos_init(ble_config_host_task);

    s_ble_initialized = true;
    ESP_LOGI(TAG, "Driver NimBLE inicializado.");
    return ESP_OK;
}

esp_err_t ble_config_service_start(void)
{
    if (!s_ble_initialized) {
        esp_err_t err = ble_config_service_init();
        if (err != ESP_OK) {
            return err;
        }
    }

    if (s_ble_active) {
        ESP_LOGI(TAG, "Serviço BLE já está ativo.");
        return ESP_OK;
    }

    s_ble_active = true;

    if (ble_hs_synced()) {
        ble_config_start_advertising();
    } else {
        ESP_LOGI(TAG, "Aguardando sincronização da stack NimBLE para iniciar anúncio...");
    }

    return ESP_OK;
}

esp_err_t ble_config_service_stop(void)
{
    if (!s_ble_active) {
        ESP_LOGW(TAG, "Serviço BLE já está inativo.");
        return ESP_OK;
    }

    s_ble_active = false;

    int rc = ble_gap_adv_stop();
    if (rc != 0 && rc != BLE_HS_EALREADY) {
        ESP_LOGW(TAG, "Aviso ao interromper anúncio BLE: rc=%d", rc);
    }

    ESP_LOGI(TAG, ">>> SERVIÇO BLE INTERROMPIDO (Sob demanda) <<<");
    return ESP_OK;
}

bool ble_config_service_is_active(void)
{
    return s_ble_active;
}

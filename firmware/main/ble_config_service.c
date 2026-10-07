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

static uint16_t s_conn_handle = BLE_HS_CONN_HANDLE_NONE;
static uint16_t s_wifi_status_val_handle = 0;

static char s_rx_ssid[33] = {0};
static char s_rx_pass[65] = {0};
static uint8_t s_wifi_status = 0; // 0=Aguardando, 1=Conectando, 2=Sucesso, 3=Erro
static ble_config_wifi_cb_t s_credentials_cb = NULL;

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
        if (event->connect.status == 0) {
            s_conn_handle = event->connect.conn_handle;
        } else {
            s_conn_handle = BLE_HS_CONN_HANDLE_NONE;
            if (s_ble_active) {
                ble_config_start_advertising();
            }
        }
        break;

    case BLE_GAP_EVENT_DISCONNECT:
        ESP_LOGI(TAG, "[BLE GAP] Dispositivo desconectado: razão=%d", event->disconnect.reason);
        s_conn_handle = BLE_HS_CONN_HANDLE_NONE;
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

/* UUIDs do Serviço e Características GATT */
static const ble_uuid16_t gatt_svc_config_uuid = BLE_UUID16_INIT(0xFF00);
static const ble_uuid16_t gatt_chr_dev_id_uuid = BLE_UUID16_INIT(0xFF01);
static const ble_uuid16_t gatt_chr_wifi_ssid_uuid = BLE_UUID16_INIT(0xFF02);
static const ble_uuid16_t gatt_chr_wifi_pass_uuid = BLE_UUID16_INIT(0xFF03);
static const ble_uuid16_t gatt_chr_wifi_status_uuid = BLE_UUID16_INIT(0xFF04);

static int ble_config_gatt_access(uint16_t conn_handle, uint16_t attr_handle,
                                  struct ble_gatt_access_ctxt *ctxt, void *arg)
{
    uint16_t uuid16 = ble_uuid_u16(ctxt->chr->uuid);
    int rc;

    switch (uuid16) {
    case 0xFF01: /* Device ID (Read Only) */
        if (ctxt->op == BLE_GATT_ACCESS_OP_READ_CHR) {
            char short_id[16] = {0};
            device_id_get_short(short_id, sizeof(short_id));
            rc = os_mbuf_append(ctxt->om, short_id, strlen(short_id));
            return rc == 0 ? 0 : BLE_ATT_ERR_INSUFFICIENT_RES;
        }
        break;

    case 0xFF02: /* Wi-Fi SSID (Write Only) */
        if (ctxt->op == BLE_GATT_ACCESS_OP_WRITE_CHR) {
            uint16_t len = OS_MBUF_PKTLEN(ctxt->om);
            if (len >= sizeof(s_rx_ssid)) {
                return BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN;
            }
            rc = ble_hs_mbuf_to_flat(ctxt->om, s_rx_ssid, len, NULL);
            if (rc != 0) {
                return BLE_ATT_ERR_UNLIKELY;
            }
            s_rx_ssid[len] = '\0';
            ESP_LOGI(TAG, "BLE SSID recebido: '%s'", s_rx_ssid);
            return 0;
        }
        break;

    case 0xFF03: /* Wi-Fi Password (Write Only) */
        if (ctxt->op == BLE_GATT_ACCESS_OP_WRITE_CHR) {
            uint16_t len = OS_MBUF_PKTLEN(ctxt->om);
            if (len >= sizeof(s_rx_pass)) {
                return BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN;
            }
            rc = ble_hs_mbuf_to_flat(ctxt->om, s_rx_pass, len, NULL);
            if (rc != 0) {
                return BLE_ATT_ERR_UNLIKELY;
            }
            s_rx_pass[len] = '\0';
            ESP_LOGI(TAG, "BLE Senha recebida (tamanho: %d)", len);

            if (strlen(s_rx_ssid) > 0 && s_credentials_cb != NULL) {
                s_credentials_cb(s_rx_ssid, s_rx_pass);
            }
            return 0;
        }
        break;

    case 0xFF04: /* Wi-Fi Status (Read / Notify) */
        if (ctxt->op == BLE_GATT_ACCESS_OP_READ_CHR) {
            rc = os_mbuf_append(ctxt->om, &s_wifi_status, sizeof(s_wifi_status));
            return rc == 0 ? 0 : BLE_ATT_ERR_INSUFFICIENT_RES;
        }
        break;

    default:
        break;
    }

    return BLE_ATT_ERR_UNLIKELY;
}

static const struct ble_gatt_svc_def s_gatt_svcs[] = {
    {
        .type = BLE_GATT_SVC_TYPE_PRIMARY,
        .uuid = &gatt_svc_config_uuid.u,
        .characteristics = (struct ble_gatt_chr_def[]) {
            {
                .uuid = &gatt_chr_dev_id_uuid.u,
                .access_cb = ble_config_gatt_access,
                .flags = BLE_GATT_CHR_F_READ,
            },
            {
                .uuid = &gatt_chr_wifi_ssid_uuid.u,
                .access_cb = ble_config_gatt_access,
                .flags = BLE_GATT_CHR_F_WRITE,
            },
            {
                .uuid = &gatt_chr_wifi_pass_uuid.u,
                .access_cb = ble_config_gatt_access,
                .flags = BLE_GATT_CHR_F_WRITE,
            },
            {
                .uuid = &gatt_chr_wifi_status_uuid.u,
                .access_cb = ble_config_gatt_access,
                .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_NOTIFY,
                .val_handle = &s_wifi_status_val_handle,
            },
            { 0 } /* Terminação das características */
        },
    },
    { 0 } /* Terminação dos serviços */
};

/**
 * @brief Configura e dispara os anúncios BLE GAP com o nome do dispositivo.
 */
static void ble_config_start_advertising(void)
{
    struct ble_hs_adv_fields fields;
    struct ble_hs_adv_fields rsp_fields;
    struct ble_gap_adv_params adv_params;
    int rc;

    char ble_name[32] = {0};
    device_id_get_ble_name(ble_name, sizeof(ble_name));

    rc = ble_svc_gap_device_name_set(ble_name);
    if (rc != 0) {
        ESP_LOGE(TAG, "Erro ao definir nome GAP no NimBLE: rc=%d", rc);
    }

    /* 1. Pacote de Anúncio Principal (Advertising Data - max 31 bytes)
     * Flags (3 bytes) + Service UUID 16-bit (4 bytes) + Nome completo (24 bytes) = 31 bytes <= 31 bytes
     */
    memset(&fields, 0, sizeof(fields));
    fields.flags = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP;

    /* Inclui o UUID de Serviço no Anúncio para os scanners mobile identificarem */
    fields.uuids16 = (ble_uuid16_t[]){ BLE_UUID16_INIT(0xFF00) };
    fields.num_uuids16 = 1;
    fields.uuids16_is_complete = 1;

    /* 2. Pacote de Resposta de Escaneamento (Scan Response Data - max 31 bytes) */
    memset(&rsp_fields, 0, sizeof(rsp_fields));
    rsp_fields.name = (uint8_t *)ble_name;
    rsp_fields.name_len = strlen(ble_name);
    rsp_fields.name_is_complete = 1;

    rc = ble_gap_adv_rsp_set_fields(&rsp_fields);
    if (rc != 0) {
        ESP_LOGW(TAG, "Aviso ao definir campos de resposta de escaneamento: rc=%d", rc);
    }

    rc = ble_gap_adv_set_fields(&fields);
    if (rc != 0) {
        ESP_LOGE(TAG, "Erro ao definir campos de anúncio BLE: rc=%d", rc);
        return;
    }

    /* 3. Parâmetros de anúncios indiretos conectáveis */
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
        ESP_LOGI(TAG, ">>> UUID de Serviço: 0xFF00 <<<");
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

    /* Registra serviço GATT customizado no servidor NimBLE */
    rc = ble_gatts_count_cfg(s_gatt_svcs);
    if (rc != 0) {
        ESP_LOGE(TAG, "Erro em ble_gatts_count_cfg: rc=%d", rc);
        return ESP_FAIL;
    }

    rc = ble_gatts_add_svcs(s_gatt_svcs);
    if (rc != 0) {
        ESP_LOGE(TAG, "Erro em ble_gatts_add_svcs: rc=%d", rc);
        return ESP_FAIL;
    }

    /* Inicia o Servidor GATT */
    rc = ble_gatts_start();
    if (rc != 0) {
        ESP_LOGE(TAG, "Erro em ble_gatts_start: rc=%d", rc);
        return ESP_FAIL;
    }

    /* Configuração das callbacks */
    ble_hs_cfg.reset_cb = ble_config_on_reset;
    ble_hs_cfg.sync_cb = ble_config_on_sync;

    /* Dispara a thread FreeRTOS para a stack NimBLE */
    nimble_port_freertos_init(ble_config_host_task);

    s_ble_initialized = true;
    ESP_LOGI(TAG, "Driver NimBLE inicializado com sucesso.");
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

void ble_config_service_set_credentials_cb(ble_config_wifi_cb_t cb)
{
    s_credentials_cb = cb;
}

void ble_config_service_set_wifi_status(uint8_t status)
{
    s_wifi_status = status;
    ESP_LOGI(TAG, "Status Wi-Fi atualizado via BLE: %d", status);

    if (s_conn_handle != BLE_HS_CONN_HANDLE_NONE && s_wifi_status_val_handle != 0) {
        struct os_mbuf *om = ble_hs_mbuf_from_flat(&s_wifi_status, sizeof(s_wifi_status));
        if (om != NULL) {
            int rc = ble_gatts_notify_custom(s_conn_handle, s_wifi_status_val_handle, om);
            if (rc != 0) {
                ESP_LOGW(TAG, "Aviso ao enviar notificação BLE: rc=%d", rc);
            } else {
                ESP_LOGI(TAG, "Notificação BLE enviada: status=%d", status);
            }
        }
    }
}


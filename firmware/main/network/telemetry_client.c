#include "telemetry_client.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"
#include "esp_log.h"
#include "esp_http_client.h"
#include "wifi_manager.h"

static const char *TAG = "TELEMETRY_CLIENT";

#ifndef CONFIG_BACKEND_TELEMETRY_URL
#define CONFIG_BACKEND_TELEMETRY_URL "http://192.168.1.14:8081/api/v1/telemetry"
#endif

#define TELEMETRY_QUEUE_SIZE 10

static QueueHandle_t s_telemetry_queue = NULL;
static char s_backend_url[128] = CONFIG_BACKEND_TELEMETRY_URL;

static void telemetry_task(void *pvParameters)
{
    telemetry_payload_t payload;
    char json_buffer[384];

    while (1) {
        if (xQueueReceive(s_telemetry_queue, &payload, portMAX_DELAY) == pdTRUE) {
            if (!wifi_manager_is_connected()) {
                ESP_LOGW(TAG, "Wi-Fi desconectado. Telemetria descartada para deviceId: %s", payload.device_id);
                continue;
            }

            if (payload.absence_duration_minutes > 0.0) {
                snprintf(json_buffer, sizeof(json_buffer),
                         "{\"deviceId\":\"%s\",\"occupancyStatus\":\"%s\",\"acStatus\":%s,\"currentTemperature\":%.1f,\"targetTemperature\":%.1f,\"wasteDetected\":%s,\"absenceDurationMinutes\":%.2f}",
                         payload.device_id,
                         payload.occupancy_status,
                         payload.ac_status ? "true" : "false",
                         payload.current_temperature,
                         payload.target_temperature,
                         payload.waste_detected ? "true" : "false",
                         payload.absence_duration_minutes);
            } else {
                snprintf(json_buffer, sizeof(json_buffer),
                         "{\"deviceId\":\"%s\",\"occupancyStatus\":\"%s\",\"acStatus\":%s,\"currentTemperature\":%.1f,\"targetTemperature\":%.1f,\"wasteDetected\":%s}",
                         payload.device_id,
                         payload.occupancy_status,
                         payload.ac_status ? "true" : "false",
                         payload.current_temperature,
                         payload.target_temperature,
                         payload.waste_detected ? "true" : "false");
            }

            ESP_LOGI(TAG, "Enviando POST para %s | Payload: %s", s_backend_url, json_buffer);

            esp_http_client_config_t config = {
                .url = s_backend_url,
                .method = HTTP_METHOD_POST,
                .timeout_ms = 5000,
            };

            esp_http_client_handle_t client = esp_http_client_init(&config);
            if (client == NULL) {
                ESP_LOGE(TAG, "Falha ao inicializar esp_http_client");
                continue;
            }

            esp_http_client_set_header(client, "Content-Type", "application/json");
            esp_http_client_set_post_field(client, json_buffer, strlen(json_buffer));

            esp_err_t err = esp_http_client_perform(client);
            if (err == ESP_OK) {
                int status_code = esp_http_client_get_status_code(client);
                int content_len = esp_http_client_get_content_length(client);
                ESP_LOGI(TAG, "HTTP POST executado com sucesso: Status = %d, Content-Length = %d",
                         status_code, content_len);
            } else {
                ESP_LOGE(TAG, "Falha na requisição HTTP: %s", esp_err_to_name(err));
            }

            esp_http_client_cleanup(client);
        }
    }
}

esp_err_t telemetry_client_init(const char *backend_url)
{
    if (backend_url && strlen(backend_url) > 0) {
        strncpy(s_backend_url, backend_url, sizeof(s_backend_url) - 1);
        s_backend_url[sizeof(s_backend_url) - 1] = '\0';
    }

    if (s_telemetry_queue == NULL) {
        s_telemetry_queue = xQueueCreate(TELEMETRY_QUEUE_SIZE, sizeof(telemetry_payload_t));
        if (s_telemetry_queue == NULL) {
            ESP_LOGE(TAG, "Falha ao criar fila de telemetria");
            return ESP_ERR_NO_MEM;
        }

        // Tarefa dedicada de envio HTTP rodando no Core 0 (junto com a stack Wi-Fi/IP)
        BaseType_t ret = xTaskCreatePinnedToCore(
            telemetry_task,
            "telemetry_task",
            4096,
            NULL,
            3,
            NULL,
            0
        );

        if (ret != pdPASS) {
            ESP_LOGE(TAG, "Falha ao criar tarefa de telemetria");
            return ESP_FAIL;
        }
    }

    ESP_LOGI(TAG, "Cliente de telemetria inicializado com URL: %s", s_backend_url);
    return ESP_OK;
}

esp_err_t telemetry_client_send_async(const telemetry_payload_t *payload)
{
    if (!payload || !s_telemetry_queue) {
        return ESP_ERR_INVALID_STATE;
    }

    if (xQueueSend(s_telemetry_queue, payload, 0) != pdTRUE) {
        ESP_LOGW(TAG, "Fila de telemetria cheia, mensagem descartada.");
        return ESP_ERR_NO_MEM;
    }

    return ESP_OK;
}

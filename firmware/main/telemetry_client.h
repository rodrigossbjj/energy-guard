#ifndef TELEMETRY_CLIENT_H
#define TELEMETRY_CLIENT_H

#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    char device_id[32];
    char occupancy_status[32]; // "OCCUPIED", "EMPTY", "ALERT_DESPERDICIO"
    bool ac_status;
    float current_temperature;
    float target_temperature;
    bool waste_detected;
    double absence_duration_minutes; // Minutos de ausência encerrada (> 0.0)
} telemetry_payload_t;

/**
 * @brief Inicializa a tarefa e fila assíncrona de telemetria HTTP.
 * @param backend_url URL padrão do backend (se NULL usa CONFIG_BACKEND_TELEMETRY_URL)
 * @return esp_err_t ESP_OK em caso de sucesso.
 */
esp_err_t telemetry_client_init(const char *backend_url);

/**
 * @brief Enfileira assincronamente um pacote de telemetria para envio via HTTP POST.
 *        Não bloqueia a tarefa chamadora.
 * @param payload Dados de telemetria a enviar.
 * @return esp_err_t ESP_OK se enfileirado com sucesso.
 */
esp_err_t telemetry_client_send_async(const telemetry_payload_t *payload);

#ifdef __cplusplus
}
#endif

#endif // TELEMETRY_CLIENT_H

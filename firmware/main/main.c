/*
 * TESTE DE SENSORES - DHT22 + PIR HC-SR501
 * Projeto: Sistema de Monitoramento de Desperdício Energético
 *
 * Arquitetura Modular ESP-IDF (FreeRTOS)
 */

#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"

#include "led_indicator.h"
#include "pir_sensor.h"
#include "dht22_sensor.h"

static const char *TAG = "SENSOR_TEST";

// Instâncias dos Sensores e Dispositivos
static pir_sensor_t s_pir;
static dht22_sensor_t s_dht;

// Contadores de diagnóstico
static int s_leituras_ok = 0;
static int s_leituras_falhas = 0;

static void verificar_pir(void)
{
    bool mudou_estado = false;
    bool ocupado = pir_sensor_update(&s_pir, &mudou_estado);

    if (mudou_estado) {
        if (ocupado) {
            ESP_LOGI(TAG, ">>> [PIR] MOVIMENTO DETECTADO  (deteccao #%d)", s_pir.motion_count);
        } else {
            ESP_LOGI(TAG, ">>> [PIR] movimento cessou / sala parada");
        }
    }
}

static void verificar_dht(void)
{
    float temp = 0.0f;
    float umid = 0.0f;

    esp_err_t err = dht22_sensor_read(&s_dht, &temp, &umid);

    if (err != ESP_OK) {
        s_leituras_falhas++;
        ESP_LOGW(TAG, "[DHT] ERRO na leitura! (falhas: %d, err_code: 0x%x)", s_leituras_falhas, err);
        return;
    }

    s_leituras_ok++;

    // -------------------------------------------------------
    // CONTROLE DO LED PELA TEMPERATURA
    // -------------------------------------------------------
    if (temp < 24.0f) {
        led_indicator_set(true);
        ESP_LOGI(TAG, ">>> [DHT] Temperatura abaixo de 24 C - LED LIGADO");
    } else {
        led_indicator_set(false);
        ESP_LOGI(TAG, ">>> [DHT] Temperatura igual/acima de 24 C - LED DESLIGADO");
    }

    // Sensação térmica
    float sensacao = dht22_compute_heat_index(temp, umid);
    bool sala_ocupada = (s_pir.last_state == true);

    ESP_LOGI(TAG, "[DHT] Temp: %.1f C  |  Umid: %.1f %%  |  Sensacao: %.1f C  |  Sala: %s",
             temp, umid, sensacao, sala_ocupada ? "OCUPADA" : "sem atividade");

    // Resumo a cada 10 leituras com sucesso
    if (s_leituras_ok % 10 == 0) {
        printf("\n--- RESUMO DO DIAGNOSTICO ---\n");
        printf("Leituras DHT OK      : %d\n", s_leituras_ok);
        printf("Leituras DHT com erro: %d\n", s_leituras_falhas);
        printf("Deteccoes do PIR     : %d\n", s_pir.motion_count);
        printf("-----------------------------\n\n");
    }
}

void app_main(void)
{
    // Inicialização dos Módulos
    led_indicator_init(LED_INDICATOR_DEFAULT_GPIO);
    pir_sensor_init(&s_pir, PIR_SENSOR_DEFAULT_GPIO);
    dht22_sensor_init(&s_dht, DHT22_SENSOR_DEFAULT_GPIO);

    printf("\n========================================\n");
    printf("  TESTE DE SENSORES - INICIANDO (ESP-IDF)\n");
    printf("========================================\n");
    printf("Pino DHT22 : GPIO %d\n", DHT22_SENSOR_DEFAULT_GPIO);
    printf("Pino PIR   : GPIO %d\n", PIR_SENSOR_DEFAULT_GPIO);
    printf("Pino LED   : GPIO %d\n", LED_INDICATOR_DEFAULT_GPIO);
    printf("----------------------------------------\n");
    printf("O PIR precisa de 30-60s para estabilizar.\n");
    printf("----------------------------------------\n\n");

    while (1) {
        verificar_pir();
        verificar_dht();

        // Loop a cada 2 segundos (intervalo mínimo do DHT22)
        vTaskDelay(pdMS_TO_TICKS(2000));
    }
}

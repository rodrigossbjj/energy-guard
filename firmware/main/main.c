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
#include "driver/gpio.h"

#include "led_indicator.h"
#include "pir_sensor.h"
#include "dht22_sensor.h"

static const char *TAG = "ENERGY_GUARD";

// Instâncias dos Sensores e Dispositivos
static pir_sensor_t s_pir;
static dht22_sensor_t s_dht;

// Contadores de diagnóstico
static int s_leituras_ok = 0;
static int s_leituras_falhas = 0;

/**
 * @brief Monitora o sensor PIR e loga alterações no estado de presença.
 */
static void monitorar_pir(void)
{
    bool mudou_estado = false;
    bool ocupado = pir_sensor_update(&s_pir, &mudou_estado);

    if (mudou_estado) {
        if (ocupado) {
            ESP_LOGI(TAG, ">>> [PIR] MOVIMENTO DETECTADO (detecção #%d)", s_pir.motion_count);
        } else {
            ESP_LOGI(TAG, ">>> [PIR] Movimento cessou / Sala livre");
        }
    }
}

/**
 * @brief Aplica a regra de acionamento do indicador (LED) com base na temperatura e presença.
 * @param temp Temperatura medida em °C.
 * @param sala_ocupada Indica se o PIR detectou presença na sala.
 */
static void processar_regra_atentuacao(float temp, bool sala_ocupada)
{
    // Regra: Liga indicador se temp < 24°C ou se a sala estiver ocupada
    if (temp < 24.0f || sala_ocupada) {
        led_indicator_set(true);
        ESP_LOGI(TAG, ">>> [LED LIGADO] Temp: %.1f C | Presença: %s",
                 temp, sala_ocupada ? "SIM" : "NÃO");
    } else {
        led_indicator_set(false);
        ESP_LOGI(TAG, ">>> [LED DESLIGADO] Temp: %.1f C | Presença: NÃO", temp);
    }
}

/**
 * @brief Imprime o resumo de diagnóstico do sistema no console serial.
 */
static void exibir_diagnostico(void)
{
    printf("\n--- RESUMO DO DIAGNÓSTICO ---\n");
    printf("Leituras DHT OK      : %d\n", s_leituras_ok);
    printf("Leituras DHT com erro: %d\n", s_leituras_falhas);
    printf("Detecções do PIR     : %d\n", s_pir.motion_count);
    printf("-----------------------------\n\n");
}

/**
 * @brief Realiza a leitura ambiental (DHT22), aciona a regra de atuação e gera logs.
 */
static void monitorar_ambiente(void)
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

    bool sala_ocupada = s_pir.last_state;

    // Processa regras de atuação baseadas nos sensores
    processar_regra_atentuacao(temp, sala_ocupada);

    // Sensação térmica e log das variáveis ambientais
    float sensacao = dht22_compute_heat_index(temp, umid);
    ESP_LOGI(TAG, "[DHT] Temp: %.1f C | Umid: %.1f %% | Sensação: %.1f C | Sala: %s",
             temp, umid, sensacao, sala_ocupada ? "OCUPADA" : "LIVRE");

    // Resumo periódico a cada 10 leituras com sucesso
    if (s_leituras_ok % 10 == 0) {
        exibir_diagnostico();
    }
}

void app_main(void)
{
    // Inicialização dos Módulos
    led_indicator_init(LED_INDICATOR_DEFAULT_GPIO);
    pir_sensor_init(&s_pir, PIR_SENSOR_DEFAULT_GPIO);
    dht22_sensor_init(&s_dht, DHT22_SENSOR_DEFAULT_GPIO);

    printf("\n========================================\n");
    printf("  MONITORAMENTO ENERGY GUARD (ESP-IDF)\n");
    printf("========================================\n");
    printf("Pino DHT22 : GPIO %d\n", DHT22_SENSOR_DEFAULT_GPIO);
    printf("Pino PIR   : GPIO %d\n", PIR_SENSOR_DEFAULT_GPIO);
    printf("Pino LED   : GPIO %d\n", LED_INDICATOR_DEFAULT_GPIO);
    printf("----------------------------------------\n");
    printf("O PIR precisa de 30-60s para estabilizar.\n");
    printf("----------------------------------------\n\n");

    while (1) {
        monitorar_pir();
        monitorar_ambiente();

        // Loop a cada 2 segundos (intervalo mínimo recomendado do DHT22)
        vTaskDelay(pdMS_TO_TICKS(2000));
    }
}

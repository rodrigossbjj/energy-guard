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
#include "wifi_manager.h"
#include "device_id.h"

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
 * @brief Aplica a regra de acionamento dos indicadores (LEDs) com base na temperatura e presença.
 * @param temp Temperatura medida em °C.
 * @param sala_ocupada Indica se o PIR detectou presença na sala.
 */
static void processar_regra_atentuacao(float temp, bool sala_ocupada)
{
    // Nova Regra: LED Vermelho (D27) aceso se sem presença E temp < 24°C
    // LED Verde (D26) aceso nas demais condições ("Tudo bem")
    bool condicao_economia = (temp < 24.0f || sala_ocupada);
    led_indicator_set_condition(condicao_economia);

    if (condicao_economia) {
        ESP_LOGI(TAG, ">>> [DHT] Temperatura abaixo de 24°C e PIR sem ocupação - LED Vermelho (D27)");
    } else {
        ESP_LOGI(TAG, ">>> [DHT] Condição normal (Tudo bem) - LED Verde (D26)");
    }
}

/**
 * @brief Imprime o resumo de diagnóstico do sistema no console serial.
 */
static void exibir_diagnostico(void)
{
    char ip_str[16] = {0};
    wifi_manager_get_ip_str(ip_str, sizeof(ip_str));

    printf("\n--- RESUMO DO DIAGNÓSTICO ---\n");
    printf("Status Wi-Fi         : %s (IP: %s)\n",
           wifi_manager_is_connected() ? "CONECTADO" : "DESCONECTADO", ip_str);
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
    ESP_LOGI(TAG, "[DHT] Temp: %.1f C | Umid: %.1f %% | Sensação: %.1f C | Sala: %s | Wi-Fi: %s",
             temp, umid, sensacao, sala_ocupada ? "OCUPADA" : "LIVRE",
             wifi_manager_is_connected() ? "ON" : "OFF");

    // Resumo periódico a cada 10 leituras com sucesso
    if (s_leituras_ok % 10 == 0) {
        exibir_diagnostico();
    }
}

void app_main(void)
{
    // Inicialização dos Módulos Hardware
    led_indicator_init(LED_INDICATOR_RED_GPIO, LED_INDICATOR_GREEN_GPIO);
    pir_sensor_init(&s_pir, PIR_SENSOR_DEFAULT_GPIO);
    dht22_sensor_init(&s_dht, DHT22_SENSOR_DEFAULT_GPIO);

    printf("\n========================================\n");
    printf("  MONITORAMENTO ENERGY GUARD (ESP-IDF)\n");
    printf("========================================\n");
    printf("Pino DHT22       : GPIO %d\n", DHT22_SENSOR_DEFAULT_GPIO);
    printf("Pino PIR         : GPIO %d\n", PIR_SENSOR_DEFAULT_GPIO);
    printf("LED Vermelho (D27): GPIO %d\n", LED_INDICATOR_RED_GPIO);
    printf("LED Verde (D26)   : GPIO %d\n", LED_INDICATOR_GREEN_GPIO);
    printf("----------------------------------------\n");
    printf("O PIR precisa de 30-60s para estabilizar.\n");
    printf("----------------------------------------\n\n");

    // Inicialização da Conexão Wi-Fi
    ESP_LOGI(TAG, "Iniciando gerenciador de Wi-Fi...");
    esp_err_t wifi_ret = wifi_manager_init();
    if (wifi_ret == ESP_OK) {
        char ip_buf[16] = {0};
        wifi_manager_get_ip_str(ip_buf, sizeof(ip_buf));
        ESP_LOGI(TAG, "Wi-Fi pronto! IP Atribuído: %s", ip_buf);
    } else {
        ESP_LOGW(TAG, "Operando em Modo Offline (Wi-Fi não conectado).");
    }

    // Identificação Única da Placa (Etapa 1)
    char mac_str[18] = {0};
    char short_id[16] = {0};
    char ble_name[32] = {0};
    device_id_get_mac_str(mac_str, sizeof(mac_str));
    device_id_get_short(short_id, sizeof(short_id));
    device_id_get_ble_name(ble_name, sizeof(ble_name));

    ESP_LOGI(TAG, "========================================");
    ESP_LOGI(TAG, "IDENTIFICAÇÃO ÚNICA DA PLACA");
    ESP_LOGI(TAG, "MAC Address STA  : %s", mac_str);
    ESP_LOGI(TAG, "ID Curto         : %s", short_id);
    ESP_LOGI(TAG, "Nome Anúncio BLE : %s", ble_name);
    ESP_LOGI(TAG, "========================================");

    TickType_t ultima_leitura_dht = xTaskGetTickCount();

    while (1) {
        monitorar_pir();
        led_indicator_update();

        // Leitura do DHT a cada 2000 ms (2 segundos)
        if ((xTaskGetTickCount() - ultima_leitura_dht) >= pdMS_TO_TICKS(2000)) {
            ultima_leitura_dht = xTaskGetTickCount();
            monitorar_ambiente();
        }

        vTaskDelay(pdMS_TO_TICKS(20)); // Atualiza LEDs e PIR suavemente a cada 20ms
    }
}


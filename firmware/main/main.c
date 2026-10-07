/*
 * SISTEMA DE MONITORAMENTO ENERGY GUARD (ESP-IDF)
 * Arquitetura Modular FreeRTOS
 */

#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "driver/gpio.h"

#include "led_indicator.h"
#include "pir_sensor.h"
#include "dht22_sensor.h"
#include "wifi_manager.h"
#include "device_id.h"
#include "config_button.h"
#include "ble_config_service.h"

static const char *TAG = "ENERGY_GUARD";

// Instâncias dos Sensores e Dispositivos
static pir_sensor_t s_pir;
static dht22_sensor_t s_dht;
static config_button_t s_btn_config;

// Contadores de diagnóstico
static int s_leituras_ok = 0;
static int s_leituras_falhas = 0;

typedef struct {
    char ssid[33];
    char password[65];
} wifi_prov_req_t;

static QueueHandle_t s_wifi_prov_queue = NULL;

static void wifi_prov_task(void *pvParameters)
{
    wifi_prov_req_t req;
    while (1) {
        if (xQueueReceive(s_wifi_prov_queue, &req, portMAX_DELAY) == pdTRUE) {
            ESP_LOGI(TAG, ">>> Recebidas credenciais Wi-Fi via BLE! SSID: '%s'", req.ssid);
            
            // Status BLE = 1 (Conectando)
            ble_config_service_set_wifi_status(1);

            esp_err_t err = wifi_manager_connect_with_credentials(req.ssid, req.password);
            if (err == ESP_OK) {
                ESP_LOGI(TAG, ">>> Conexão Wi-Fi BEM-SUCEDIDA! Notificando app e desligando BLE...");
                // Status BLE = 2 (Sucesso)
                ble_config_service_set_wifi_status(2);

                vTaskDelay(pdMS_TO_TICKS(2000));

                ble_config_service_stop();
                led_indicator_set_config_mode(false);
            } else {
                ESP_LOGE(TAG, ">>> Falha na conexão Wi-Fi com as credenciais enviadas.");
                // Status BLE = 3 (Erro)
                ble_config_service_set_wifi_status(3);
            }
        }
    }
}

static void on_wifi_credentials_received(const char *ssid, const char *password)
{
    if (!ssid || !s_wifi_prov_queue) {
        return;
    }

    wifi_prov_req_t req = {0};
    strncpy(req.ssid, ssid, sizeof(req.ssid) - 1);
    if (password) {
        strncpy(req.password, password, sizeof(req.password) - 1);
    }

    xQueueSend(s_wifi_prov_queue, &req, 0);
}

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
    // LED Vermelho (D27) aceso se sem presença E temp < 24°C
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

/**
 * @brief Tarefa dedicada para o monitoramento de sensores e atuadores (Core 1).
 */
static void sensor_monitoring_task(void *pvParameters)
{
    TickType_t ultima_leitura_dht = xTaskGetTickCount();

    while (1) {
        bool modo_config_ativo = ble_config_service_is_active();

        // Monitoramento constante do Botão de Configuração com Debounce
        bool btn_evento_pressionado = false;
        config_button_update(&s_btn_config, &btn_evento_pressionado);
        if (btn_evento_pressionado) {
            if (ble_config_service_is_active()) {
                ESP_LOGI(TAG, ">>> Desativando Modo de Configuração BLE. Retornando ao Modo Normal...");
                ble_config_service_stop();
                led_indicator_set_config_mode(false);
            } else {
                ESP_LOGI(TAG, ">>> Ativando Modo de Configuração BLE! Pausando sensores e piscando LED Verde (D26)...");
                ble_config_service_start();
                led_indicator_set_config_mode(true);
            }
        }

        // Atualiza animação dos LEDs (fading ou pisca em modo de configuração)
        led_indicator_update();

        // Durante o Modo de Configuração BLE, PAUSA a leitura do PIR e DHT22
        // para dedicar a execução totalmente ao modo de configuração
        if (!modo_config_ativo) {
            monitorar_pir();

            // Leitura do DHT22 a cada 2 segundos
            if ((xTaskGetTickCount() - ultima_leitura_dht) >= pdMS_TO_TICKS(2000)) {
                ultima_leitura_dht = xTaskGetTickCount();
                monitorar_ambiente();
            }
        }

        vTaskDelay(pdMS_TO_TICKS(20)); // Frequência de 50 Hz
    }
}

/**
 * @brief Tarefa assíncrona para inicialização e conexão do Wi-Fi (Core 0).
 */
static void wifi_init_task(void *pvParameters)
{
    ESP_LOGI(TAG, "Iniciando gerenciador de Wi-Fi em segundo plano...");
    esp_err_t wifi_ret = wifi_manager_init();
    if (wifi_ret == ESP_OK) {
        char ip_buf[16] = {0};
        wifi_manager_get_ip_str(ip_buf, sizeof(ip_buf));
        ESP_LOGI(TAG, "Wi-Fi pronto! IP Atribuído: %s", ip_buf);
    } else {
        ESP_LOGW(TAG, "Operando em Modo Offline (Wi-Fi não conectado).");
    }
    vTaskDelete(NULL);
}

void app_main(void)
{
    // Inicialização do NVS Flash
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    // Inicialização dos Módulos Hardware
    led_indicator_init(LED_INDICATOR_RED_GPIO, LED_INDICATOR_GREEN_GPIO);
    pir_sensor_init(&s_pir, PIR_SENSOR_DEFAULT_GPIO);
    dht22_sensor_init(&s_dht, DHT22_SENSOR_DEFAULT_GPIO);
    config_button_init(&s_btn_config, CONFIG_BUTTON_DEFAULT_GPIO, CONFIG_BUTTON_DEFAULT_ACTIVE_LEVEL);

    // Fila e Tarefa para processamento assíncrono de credenciais Wi-Fi via BLE
    s_wifi_prov_queue = xQueueCreate(2, sizeof(wifi_prov_req_t));
    xTaskCreatePinnedToCore(wifi_prov_task, "wifi_prov_task", 4096, NULL, 4, NULL, 0);

    // Inicialização do NimBLE (Bluetooth vem DESLIGADO por padrão)
    ble_config_service_init();
    ble_config_service_set_credentials_cb(on_wifi_credentials_received);

    printf("\n========================================\n");
    printf("  MONITORAMENTO ENERGY GUARD (ESP-IDF)\n");
    printf("========================================\n");
    printf("Pino DHT22       : GPIO %d\n", DHT22_SENSOR_DEFAULT_GPIO);
    printf("Pino PIR         : GPIO %d\n", PIR_SENSOR_DEFAULT_GPIO);
    printf("Botão Config     : GPIO %d\n", CONFIG_BUTTON_DEFAULT_GPIO);
    printf("LED Vermelho (D27): GPIO %d\n", LED_INDICATOR_RED_GPIO);
    printf("LED Verde (D26)   : GPIO %d\n", LED_INDICATOR_GREEN_GPIO);
    printf("----------------------------------------\n");
    printf("O PIR precisa de 30-60s para estabilizar.\n");
    printf("----------------------------------------\n\n");

    // Identificação Única da Placa
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

    // Cria tarefa para inicialização do Wi-Fi no Core 0 sem bloquear a execução principal
    xTaskCreatePinnedToCore(wifi_init_task, "wifi_init_task", 4096, NULL, 3, NULL, 0);

    // Cria tarefa dedicada para sensores, atuadores e botão no Core 1
    xTaskCreatePinnedToCore(sensor_monitoring_task, "sensor_task", 4096, NULL, 5, NULL, 1);
}

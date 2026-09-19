#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "esp_log.h"

// Pino D27 = GPIO 27
#define LED_PIN GPIO_NUM_27

static const char *TAG = "BLINK_D27";

void app_main(void)
{
    // Configura o pino GPIO 27 como saída de sinal
    gpio_reset_pin(LED_PIN);
    gpio_set_direction(LED_PIN, GPIO_MODE_OUTPUT);

    ESP_LOGI(TAG, "Iniciando pisca-pisca no GPIO 27 (D27)...");

    while (1) {
        // Liga o LED (Nível Alto / 3.3V)
        gpio_set_level(LED_PIN, 1);
        ESP_LOGI(TAG, "LED no D27: LIGADO");
        vTaskDelay(pdMS_TO_TICKS(300)); // Aguarda 1 segundo

        // Desliga o LED (Nível Baixo / 0V)
        gpio_set_level(LED_PIN, 0);
        ESP_LOGI(TAG, "LED no D27: DESLIGADO");
        vTaskDelay(pdMS_TO_TICKS(300)); // Aguarda 1 segundo
    }
}

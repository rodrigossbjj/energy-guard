#include "config_button.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static const char *TAG = "CONFIG_BUTTON";
#define DEBOUNCE_DELAY_MS 50

void config_button_init(config_button_t *dev, gpio_num_t gpio, bool active_level)
{
    if (!dev) return;

    dev->gpio = gpio;
    dev->active_level = active_level;
    dev->last_raw_state = false;
    dev->stable_state = false;
    dev->last_change_ms = 0;

    gpio_config_t io_conf = {
        .pin_bit_mask = (1ULL << gpio),
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = GPIO_PULLUP_DISABLE,    // GPIO 34 é apenas entrada e requer resistor externo
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE
    };
    gpio_config(&io_conf);

    int raw = gpio_get_level(gpio);
    bool initial_pressed = (raw == active_level);
    dev->last_raw_state = initial_pressed;
    dev->stable_state = initial_pressed;

    ESP_LOGI(TAG, "Botão de Configuração inicializado no GPIO %d (Ativo em nível %s)",
             gpio, active_level == 0 ? "LOW" : "HIGH");
}

bool config_button_update(config_button_t *dev, bool *event_pressed)
{
    if (!dev) return false;

    if (event_pressed) {
        *event_pressed = false;
    }

    int raw_level = gpio_get_level(dev->gpio);
    bool current_raw_pressed = (raw_level == dev->active_level);
    uint32_t now_ms = (uint32_t)(xTaskGetTickCount() * portTICK_PERIOD_MS);

    if (current_raw_pressed != dev->last_raw_state) {
        dev->last_raw_state = current_raw_pressed;
        dev->last_change_ms = now_ms;
    }

    if ((now_ms - dev->last_change_ms) >= DEBOUNCE_DELAY_MS) {
        if (current_raw_pressed != dev->stable_state) {
            dev->stable_state = current_raw_pressed;
            if (dev->stable_state) {
                if (event_pressed) {
                    *event_pressed = true;
                }
                ESP_LOGI(TAG, ">>> [BOTÃO] Pressionado! Solicitando entrada em Modo de Configuração.");
            } else {
                ESP_LOGI(TAG, ">>> [BOTÃO] Solto.");
            }
        }
    }

    return dev->stable_state;
}

bool config_button_is_pressed(const config_button_t *dev)
{
    if (!dev) return false;
    return dev->stable_state;
}

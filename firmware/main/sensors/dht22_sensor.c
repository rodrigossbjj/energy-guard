#include "dht22_sensor.h"
#include "esp_timer.h"
#include "esp_rom_sys.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include <math.h>

void dht22_sensor_init(dht22_sensor_t *dev, gpio_num_t gpio)
{
    if (!dev) return;
    dev->gpio = gpio;
    gpio_reset_pin(dev->gpio);
    gpio_set_direction(dev->gpio, GPIO_MODE_INPUT);
    gpio_set_pull_mode(dev->gpio, GPIO_PULLUP_ONLY);
}

static int wait_for_level(gpio_num_t gpio, int level, uint32_t timeout_us)
{
    int64_t start = esp_timer_get_time();
    while (gpio_get_level(gpio) != level) {
        if ((esp_timer_get_time() - start) > timeout_us) {
            return -1;
        }
    }
    return (int)(esp_timer_get_time() - start);
}

static portMUX_TYPE s_dht22_spinlock = portMUX_INITIALIZER_UNLOCKED;

static esp_err_t dht22_sensor_read_single(dht22_sensor_t *dev, float *temperature, float *humidity)
{
    if (!dev || !temperature || !humidity) {
        return ESP_ERR_INVALID_ARG;
    }

    uint8_t data[5] = {0, 0, 0, 0, 0};

    // Pulso de Start: nível LOW por ~20ms
    gpio_set_direction(dev->gpio, GPIO_MODE_OUTPUT);
    gpio_set_level(dev->gpio, 0);
    vTaskDelay(pdMS_TO_TICKS(20));

    // Entra na seção crítica antes da liberação do pulso e da leitura de bits (~4ms)
    // Isso bloqueia interrupções de rádio Wi-Fi durante o protocolo bit-banging
    portENTER_CRITICAL(&s_dht22_spinlock);

    // Nível HIGH por 30us e chaveia para entrada com pull-up
    gpio_set_level(dev->gpio, 1);
    esp_rom_delay_us(30);

    gpio_set_direction(dev->gpio, GPIO_MODE_INPUT);
    gpio_set_pull_mode(dev->gpio, GPIO_PULLUP_ONLY);

    // Resposta de Handshake do sensor: LOW (~80us), depois HIGH (~80us), depois LOW (~50us)
    if (wait_for_level(dev->gpio, 0, 100) < 0) { portEXIT_CRITICAL(&s_dht22_spinlock); return 0x101; }
    if (wait_for_level(dev->gpio, 1, 100) < 0) { portEXIT_CRITICAL(&s_dht22_spinlock); return 0x102; }
    if (wait_for_level(dev->gpio, 0, 100) < 0) { portEXIT_CRITICAL(&s_dht22_spinlock); return 0x103; }

    // Leitura dos 40 bits de dados (5 bytes)
    for (int i = 0; i < 40; i++) {
        // Aguarda início do bit (subida para HIGH)
        if (wait_for_level(dev->gpio, 1, 75) < 0) { portEXIT_CRITICAL(&s_dht22_spinlock); return 0x104; }

        // Mede duração em HIGH (~28us para bit 0, ~70us para bit 1)
        int high_duration = wait_for_level(dev->gpio, 0, 100);
        if (high_duration < 0) { portEXIT_CRITICAL(&s_dht22_spinlock); return 0x105; }

        // Duração HIGH > ~40us indica bit '1'
        if (high_duration > 40) {
            data[i / 8] |= (1 << (7 - (i % 8)));
        }
    }

    portEXIT_CRITICAL(&s_dht22_spinlock);

    // Validação de Checksum (CRC)
    uint8_t checksum = (data[0] + data[1] + data[2] + data[3]) & 0xFF;
    if (checksum != data[4]) {
        return ESP_ERR_INVALID_CRC;
    }

    // Extração de Umidade
    int16_t raw_hum = (data[0] << 8) | data[1];
    *humidity = raw_hum / 10.0f;

    // Extração de Temperatura
    int16_t raw_temp = ((data[2] & 0x7F) << 8) | data[3];
    if (data[2] & 0x80) {
        raw_temp = -raw_temp;
    }
    *temperature = raw_temp / 10.0f;

    return ESP_OK;
}

esp_err_t dht22_sensor_read(dht22_sensor_t *dev, float *temperature, float *humidity)
{
    esp_err_t err = ESP_FAIL;
    for (int retry = 0; retry < 3; retry++) {
        if (retry > 0) {
            vTaskDelay(pdMS_TO_TICKS(120));
        }
        err = dht22_sensor_read_single(dev, temperature, humidity);
        if (err == ESP_OK) {
            return ESP_OK;
        }
    }
    return err;
}

float dht22_compute_heat_index(float temp_c, float humidity)
{
    float tf = temp_c * 1.8f + 32.0f;
    float rh = humidity;

    float hi = 0.5f * (tf + 61.0f + ((tf - 68.0f) * 1.2f) + (rh * 0.094f));

    if (hi >= 80.0f) {
        hi = -42.379f + 2.04901523f * tf + 10.14333127f * rh
             - 0.22475541f * tf * rh - 0.00683783f * tf * tf
             - 0.05481717f * rh * rh + 0.00122874f * tf * tf * rh
             + 0.00085282f * tf * rh * rh - 0.00000199f * tf * tf * rh * rh;

        if (rh < 13.0f && tf >= 80.0f && tf <= 112.0f) {
            float adjustment = ((13.0f - rh) / 4.0f) * sqrtf((17.0f - fabsf(tf - 95.0f)) / 17.0f);
            hi -= adjustment;
        } else if (rh > 85.0f && tf >= 80.0f && tf <= 87.0f) {
            float adjustment = ((rh - 85.0f) / 10.0f) * ((87.0f - tf) / 5.0f);
            hi -= adjustment;
        }
    }

    return (hi - 32.0f) / 1.8f;
}

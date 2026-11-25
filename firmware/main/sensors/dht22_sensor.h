#ifndef DHT22_SENSOR_H
#define DHT22_SENSOR_H

#include <stdbool.h>
#include "esp_err.h"
#include "driver/gpio.h"

#define DHT22_SENSOR_DEFAULT_GPIO GPIO_NUM_4

typedef struct {
    gpio_num_t gpio;
} dht22_sensor_t;

/**
 * @brief Initialize DHT22 sensor device.
 * @param dev Pointer to dht22_sensor_t structure.
 * @param gpio GPIO number connected to DHT22 data pin.
 */
void dht22_sensor_init(dht22_sensor_t *dev, gpio_num_t gpio);

/**
 * @brief Read temperature and humidity from DHT22 sensor.
 * @param dev Pointer to dht22_sensor_t structure.
 * @param temperature Output pointer for temperature in Celsius.
 * @param humidity Output pointer for relative humidity in %.
 * @return ESP_OK on success, ESP_ERR_TIMEOUT or ESP_ERR_INVALID_CRC on failure.
 */
esp_err_t dht22_sensor_read(dht22_sensor_t *dev, float *temperature, float *humidity);

/**
 * @brief Compute heat index (sensação térmica) in Celsius.
 * @param temperature Temperature in Celsius.
 * @param humidity Humidity in %.
 * @return Sensação térmica in Celsius.
 */
float dht22_compute_heat_index(float temperature, float humidity);

#endif // DHT22_SENSOR_H

#ifndef PIR_SENSOR_H
#define PIR_SENSOR_H

#include <stdbool.h>
#include "driver/gpio.h"

#define PIR_SENSOR_DEFAULT_GPIO GPIO_NUM_17

typedef struct {
    gpio_num_t gpio;
    bool last_state;
    int motion_count;
} pir_sensor_t;

/**
 * @brief Initialize PIR motion sensor device.
 * @param dev Pointer to pir_sensor_t device structure.
 * @param gpio GPIO number connected to PIR signal pin.
 */
void pir_sensor_init(pir_sensor_t *dev, gpio_num_t gpio);

/**
 * @brief Poll current PIR sensor state and update motion count.
 * @param dev Pointer to pir_sensor_t device structure.
 * @param state_changed Pointer to bool set to true if state transitioned (HIGH<->LOW). Can be NULL.
 * @return true if motion is currently detected (HIGH), false otherwise.
 */
bool pir_sensor_update(pir_sensor_t *dev, bool *state_changed);

#endif // PIR_SENSOR_H

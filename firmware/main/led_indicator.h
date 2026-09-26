#ifndef LED_INDICATOR_H
#define LED_INDICATOR_H

#include <stdbool.h>
#include "driver/gpio.h"

#define LED_INDICATOR_DEFAULT_GPIO GPIO_NUM_27

/**
 * @brief Initialize the LED indicator GPIO.
 * @param gpio GPIO number to use for the LED.
 */
void led_indicator_init(gpio_num_t gpio);

/**
 * @brief Set the LED state (ON or OFF).
 * @param on True to turn LED on, false to turn off.
 */
void led_indicator_set(bool on);

/**
 * @brief Toggle the current LED state.
 */
void led_indicator_toggle(void);

/**
 * @brief Get current LED state.
 * @return true if ON, false if OFF.
 */
bool led_indicator_get_state(void);

#endif // LED_INDICATOR_H

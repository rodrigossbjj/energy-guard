#include "pir_sensor.h"

void pir_sensor_init(pir_sensor_t *dev, gpio_num_t gpio)
{
    if (!dev) return;
    dev->gpio = gpio;
    dev->last_state = false;
    dev->motion_count = 0;

    gpio_reset_pin(dev->gpio);
    gpio_set_direction(dev->gpio, GPIO_MODE_INPUT);
    gpio_set_pull_mode(dev->gpio, GPIO_PULLDOWN_ONLY);
}

bool pir_sensor_update(pir_sensor_t *dev, bool *state_changed)
{
    if (!dev) return false;

    bool current_state = (gpio_get_level(dev->gpio) == 1);

    if (state_changed) {
        *state_changed = (current_state != dev->last_state);
    }

    if (current_state != dev->last_state) {
        if (current_state) {
            dev->motion_count++;
        }
        dev->last_state = current_state;
    }

    return current_state;
}

#include "led_indicator.h"

static gpio_num_t s_led_gpio = LED_INDICATOR_DEFAULT_GPIO;
static bool s_led_state = false;

void led_indicator_init(gpio_num_t gpio)
{
    s_led_gpio = gpio;
    gpio_reset_pin(s_led_gpio);
    gpio_set_direction(s_led_gpio, GPIO_MODE_OUTPUT);
    led_indicator_set(false);
}

void led_indicator_set(bool on)
{
    s_led_state = on;
    gpio_set_level(s_led_gpio, on ? 1 : 0);
}

void led_indicator_toggle(void)
{
    led_indicator_set(!s_led_state);
}

bool led_indicator_get_state(void)
{
    return s_led_state;
}

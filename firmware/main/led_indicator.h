#ifndef LED_INDICATOR_H
#define LED_INDICATOR_H

#include <stdbool.h>
#include "driver/gpio.h"

#define LED_INDICATOR_RED_GPIO   GPIO_NUM_27
#define LED_INDICATOR_GREEN_GPIO GPIO_NUM_26

/**
 * @brief Inicializa a configuração dos LEDs Vermelho e Verde com PWM (LEDC).
 * @param gpio_red Pino GPIO do LED Vermelho.
 * @param gpio_green Pino GPIO do LED Verde.
 */
void led_indicator_init(gpio_num_t gpio_red, gpio_num_t gpio_green);

/**
 * @brief Define a condição do sistema (economia vs tudo bem).
 * @param condicao_economia Se true: LED Vermelho acende, LED Verde apaga.
 *                          Se false: LED Verde acende, LED Vermelho apaga.
 */
void led_indicator_set_condition(bool condicao_economia);

/**
 * @brief Atualiza a transição gradual de brilho dos LEDs. Deve ser chamada periodicamente.
 */
void led_indicator_update(void);

/**
 * @brief Obtém se a condição de economia está ativa.
 */
bool led_indicator_is_economy_mode(void);

/**
 * @brief Obtém o brilho atual do LED Vermelho (0 a 255).
 */
int led_indicator_get_red_brightness(void);

/**
 * @brief Obtém o brilho atual do LED Verde (0 a 255).
 */
int led_indicator_get_green_brightness(void);

#endif // LED_INDICATOR_H


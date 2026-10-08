#ifndef CONFIG_BUTTON_H
#define CONFIG_BUTTON_H

#include <stdbool.h>
#include "driver/gpio.h"

#define CONFIG_BUTTON_DEFAULT_GPIO GPIO_NUM_34
#define CONFIG_BUTTON_DEFAULT_ACTIVE_LEVEL 0 // 0 = Ativo em LOW (Ex: resistor pull-up externo), 1 = Ativo em HIGH

typedef struct {
    gpio_num_t gpio;
    bool active_level;       // Nível lógico quando o botão está pressionado (0=LOW, 1=HIGH)
    bool last_raw_state;     // Última leitura bruta
    bool stable_state;       // Estado filtrado com debounce
    uint32_t last_change_ms; // Timestamp da última alteração de estado
} config_button_t;

/**
 * @brief Inicializa a estrutura e o pino GPIO do botão de configuração.
 * 
 * @param dev Ponteiro para a estrutura config_button_t.
 * @param gpio Número do pino GPIO (Padrão: GPIO_NUM_34).
 * @param active_level Nível lógico ativo (0 para LOW, 1 para HIGH).
 */
void config_button_init(config_button_t *dev, gpio_num_t gpio, bool active_level);

/**
 * @brief Atualiza a leitura do botão aplicando filtro contra trepidações (debounce).
 * 
 * @param dev Ponteiro para a estrutura config_button_t.
 * @param event_pressed Ponteiro setado como true apenas no instante da borda de ativação do botão. Pode ser NULL.
 * @return true se o botão estiver atualmente no estado pressionado, false caso contrário.
 */
bool config_button_update(config_button_t *dev, bool *event_pressed);

/**
 * @brief Retorna se o botão está atualmente no estado pressionado.
 * 
 * @param dev Ponteiro para a estrutura config_button_t.
 * @return true se pressionado, false caso contrário.
 */
bool config_button_is_pressed(const config_button_t *dev);

#ifdef __cplusplus
}
#endif

#endif // CONFIG_BUTTON_H

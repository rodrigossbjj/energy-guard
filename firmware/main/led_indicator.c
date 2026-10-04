#include "led_indicator.h"
#include "driver/ledc.h"
#include "esp_timer.h"
#include "esp_log.h"

static gpio_num_t s_gpio_red = LED_INDICATOR_RED_GPIO;
static gpio_num_t s_gpio_green = LED_INDICATOR_GREEN_GPIO;

static bool s_condicao_economia = false;

static int s_brilho_red = 0;
static int s_brilho_green = 255;

static int s_alvo_red = 0;
static int s_alvo_green = 255;

#define PASSO_TRANSICAO 5
#define INTERVALO_TRANSICAO_MS 20

static int64_t s_ultima_transicao_ms = 0;

void led_indicator_init(gpio_num_t gpio_red, gpio_num_t gpio_green)
{
    s_gpio_red = gpio_red;
    s_gpio_green = gpio_green;

    // Configuração do Timer LEDC
    ledc_timer_config_t ledc_timer = {
        .speed_mode       = LEDC_LOW_SPEED_MODE,
        .timer_num        = LEDC_TIMER_0,
        .duty_resolution  = LEDC_TIMER_8_BIT, // Resolução 0-255
        .freq_hz          = 5000,
        .clk_cfg          = LEDC_AUTO_CLK
    };
    ledc_timer_config(&ledc_timer);

    // Configuração do Canal do LED Vermelho (D27)
    ledc_channel_config_t ledc_channel_red = {
        .speed_mode     = LEDC_LOW_SPEED_MODE,
        .channel        = LEDC_CHANNEL_0,
        .timer_sel      = LEDC_TIMER_0,
        .intr_type      = LEDC_INTR_DISABLE,
        .gpio_num       = s_gpio_red,
        .duty           = 0,
        .hpoint         = 0
    };
    ledc_channel_config(&ledc_channel_red);

    // Configuração do Canal do LED Verde (D26)
    ledc_channel_config_t ledc_channel_green = {
        .speed_mode     = LEDC_LOW_SPEED_MODE,
        .channel        = LEDC_CHANNEL_1,
        .timer_sel      = LEDC_TIMER_0,
        .intr_type      = LEDC_INTR_DISABLE,
        .gpio_num       = s_gpio_green,
        .duty           = 255,
        .hpoint         = 0
    };
    ledc_channel_config(&ledc_channel_green);

    s_condicao_economia = false;
    s_alvo_red = 0;
    s_alvo_green = 255;
    s_brilho_red = 0;
    s_brilho_green = 255;

    ledc_set_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_0, s_brilho_red);
    ledc_update_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_0);

    ledc_set_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_1, s_brilho_green);
    ledc_update_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_1);
}

void led_indicator_set_condition(bool condicao_economia)
{
    s_condicao_economia = condicao_economia;
    if (condicao_economia) {
        s_alvo_red = 255;
        s_alvo_green = 0;
    } else {
        s_alvo_red = 0;
        s_alvo_green = 255;
    }
}

static bool s_config_mode = false;
static int64_t s_ultimo_pisca_ms = 0;
static bool s_estado_pisca_green = false;

void led_indicator_set_config_mode(bool config_mode)
{
    s_config_mode = config_mode;
    if (!config_mode) {
        led_indicator_set_condition(s_condicao_economia);
    } else {
        s_alvo_red = 0;
        s_alvo_green = 255;
        s_estado_pisca_green = true;
    }
}

void led_indicator_update(void)
{
    int64_t agora_ms = esp_timer_get_time() / 1000;

    if (s_config_mode) {
        // Pisca lentamente o LED Verde (D26) a cada 500ms no Modo Configuração
        if (agora_ms - s_ultimo_pisca_ms >= 500) {
            s_ultimo_pisca_ms = agora_ms;
            s_estado_pisca_green = !s_estado_pisca_green;
            s_alvo_red = 0;
            s_alvo_green = s_estado_pisca_green ? 255 : 0;
        }
    }

    if (agora_ms - s_ultima_transicao_ms < INTERVALO_TRANSICAO_MS) {
        return;
    }
    s_ultima_transicao_ms = agora_ms;

    // Transição gradual do LED Vermelho (D27)
    if (s_brilho_red < s_alvo_red) {
        s_brilho_red += PASSO_TRANSICAO;
        if (s_brilho_red > s_alvo_red) s_brilho_red = s_alvo_red;
    } else if (s_brilho_red > s_alvo_red) {
        s_brilho_red -= PASSO_TRANSICAO;
        if (s_brilho_red < s_alvo_red) s_brilho_red = s_alvo_red;
    }

    // Transição gradual do LED Verde (D26)
    if (s_brilho_green < s_alvo_green) {
        s_brilho_green += PASSO_TRANSICAO;
        if (s_brilho_green > s_alvo_green) s_brilho_green = s_alvo_green;
    } else if (s_brilho_green > s_alvo_green) {
        s_brilho_green -= PASSO_TRANSICAO;
        if (s_brilho_green < s_alvo_green) s_brilho_green = s_alvo_green;
    }

    // Aplica o brilho nos canais PWM
    ledc_set_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_0, s_brilho_red);
    ledc_update_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_0);

    ledc_set_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_1, s_brilho_green);
    ledc_update_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_1);
}

bool led_indicator_is_economy_mode(void)
{
    return s_condicao_economia;
}

int led_indicator_get_red_brightness(void)
{
    return s_brilho_red;
}

int led_indicator_get_green_brightness(void)
{
    return s_brilho_green;
}


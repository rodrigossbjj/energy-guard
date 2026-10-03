idf_component_register(SRCS "main.c" "led_indicator.c" "pir_sensor.c" "dht22_sensor.c" "wifi_manager.c" "device_id.c" "config_button.c" "ble_config_service.c"
                    INCLUDE_DIRS "."
                    REQUIRES bt nvs_flash esp_driver_ledc esp_driver_gpio driver)

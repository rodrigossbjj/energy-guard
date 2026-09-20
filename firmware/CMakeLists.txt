cmake_minimum_required(VERSION 3.16)

if(NOT DEFINED ENV{IDF_PATH})
  if(EXISTS "$ENV{HOME}/.espressif/v6.1/esp-idf")
    set(ENV{IDF_PATH} "$ENV{HOME}/.espressif/v6.1/esp-idf")
  else()
    message(FATAL_ERROR "IDF_PATH environment variable is not set. Please source your ESP-IDF export script (e.g. source ~/.espressif/v6.1/esp-idf/export.sh).")
  endif()
endif()

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(energy_guard_firmware)


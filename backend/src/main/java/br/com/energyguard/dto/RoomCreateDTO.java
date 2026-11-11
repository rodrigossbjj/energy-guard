package br.com.energyguard.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RoomCreateDTO {

    @NotBlank(message = "O nome da sala é obrigatório")
    private String name;

    private String deviceId;

    private Double targetTemperature;
}

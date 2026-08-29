package br.com.energyguard.dto;

import jakarta.validation.constraints.Min;
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

    private String location;

    @Min(value = 1, message = "A capacidade mínima deve ser 1")
    private Integer capacity;

    private String deviceId;

    private Double targetTemperature;
}

package br.com.energyguard.controller;

import br.com.energyguard.dto.DeviceTelemetryDTO;
import br.com.energyguard.dto.TelemetryResponseDTO;
import br.com.energyguard.service.TelemetryService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/telemetry")
@RequiredArgsConstructor
public class TelemetryController {

    private final TelemetryService telemetryService;

    @PostMapping
    public ResponseEntity<TelemetryResponseDTO> receiveTelemetry(@Valid @RequestBody DeviceTelemetryDTO dto) {
        TelemetryResponseDTO response = telemetryService.processTelemetry(dto);
        return ResponseEntity.ok(response);
    }
}

# energy-guard

Repositório do sistema **EnergyGuard** — Plataforma IoT end-to-end para monitoramento inteligente de presença, telemetria ambiental e prevenção de desperdício energético em ambientes corporativos e residenciais.

Integração entre firmware embarcado em ESP32 (ESP-IDF / FreeRTOS), backend microserviço em Spring Boot (Java 21), banco de dados PostgreSQL, servidor de identidade Keycloak e aplicativo mobile em Flutter.

---

## Sumário

- [Visão Geral](#visão-geral)
- [Stack Tecnológica](#stack-tecnológica)
- [Responsabilidades](#responsabilidades)
- [Arquitetura](#arquitetura)
- [Fluxo no Sistema](#fluxo-no-sistema)
- [Modelo de Dados](#modelo-de-dados)
- [Endpoints da API](#endpoints-da-api)
- [Mapeamento de Hardware (ESP32)](#mapeamento-de-hardware-esp32)
- [Configuração e Execução Local](#configuração-e-execução-local)
- [Testes de Integração e API](#testes-de-integração-e-api)
- [Status de Desenvolvimento](#status-de-desenvolvimento)
- [Decisões de Arquitetura](#decisões-de-arquitetura)
- [Estrutura do Repositório](#estrutura-do-repositório)
- [Licença](#licença)

---

## Visão Geral

O **EnergyGuard** é projetado para eliminar o desperdício de energia elétrica decorrente de climatização (HVAC) e iluminação operando desnecessariamente em salas vazias ou sob condições inadequadas.

O sistema combina monitoramento sensorial de borda (*edge computing*) com uma infraestrutura centralizada:

- **Sensores na ponta**: O ESP32 mede continuamente temperatura, umidade e presença humana.
- **Atuação local imediata**: Regras de atuação embarcadas reagem em tempo real (ex: sinalização/desligamento).
- **Processamento no Backend**: A API Spring Boot valida telemetrias, consolida métricas e gerencia o ciclo de vida dos ambientes.
- **Gestão via App Mobile**: O usuário ou administrador monitora os ambientes, visualiza alertas de consumo e altera status remotamente.

---

## Stack Tecnológica

| Componente | Tecnologia | Uso |
|---|---|---|
| Linguagem Backend | Java 21 (LTS) | API REST e regras de negócio |
| Framework Backend | Spring Boot 3.3.4 | Microserviço central |
| Banco de dados | PostgreSQL 16 | Persistência de dados de salas e telemetria |
| ORM | Hibernate / Spring Data JPA | Mapeamento objeto-relacional |
| Autenticação | Keycloak (OAuth2 / OIDC) | Autenticação centralizada e autorização via JWT (RBAC) |
| Firmware | C (C11) com ESP-IDF v5.x | Sistema embarcado para ESP32 |
| RTOS | FreeRTOS | Multitasking preemptivo no ESP32 |
| Sensores | DHT22 & HC-SR501 (PIR) | Medição termohigrométrica e detecção de presença |
| Mobile | Flutter 3.x (Dart 3.x) | Aplicativo móvel para iOS, Android e Web |
| Build Tools | Maven / CMake / Pub | Ferramentas de compilação das 3 camadas |
| Containers | Docker & Docker Compose | Infraestrutura local de banco e serviços |

---

## Responsabilidades

- **Borda (ESP32 Firmware)**:
  - Leitura periódica dos sensores DHT22 (temperatura/umidade) e PIR HC-SR501 (movimento).
  - Cálculo de sensação térmica / índice de calor (*Heat Index*) no microcontrolador.
  - Execução da regra de atuação atenuada local (controle de LED/Relé).
  - Transmissão de pacotes de telemetria estruturados em JSON para o Backend.

- **Serviços Centralizados (Spring Boot Backend)**:
  - Recepção e validação do payload de telemetria emitido pelos nós IoT.
  - Validação de tokens OAuth2 emitidos pelo Keycloak em rotas protegidas.
  - Gestão de CRUD e atualização de estado de ocupação (`DISPONIVEL`, `OCUPADA`, `MANUTENCAO`, `ALERTA_DESPERDICIO`).
  - Consolidação de métricas globais e estatísticas para o Dashboard.

- **Interface de Usuário (Flutter Mobile)**:
  - Login seguro integrado ao Keycloak (OIDC Flow).
  - Visualização gráfica de temperatura, umidade e status de presença das salas.
  - Cadastro, edição e controle ativo do estado operacional de cada ambiente.

---

## Arquitetura

```
App Mobile (Flutter)
    │
    │  HTTPS REST + OAuth2 Bearer JWT
    ▼
Backend Spring Boot 3.3 (Java 21) ─────────────────┐
    │                                              │
    ├── PostgreSQL 16   (persistência relacional)  │
    └── Keycloak IAM    (validação de JWT / OIDC)  │
                            ▲                      │
                            │                      │
                   HTTP REST Telemetria            │
                            │                      │
                    Dispositivo ESP32              │
                  (ESP-IDF / FreeRTOS)             │
                    ├── Sensor DHT22               │
                    ├── Sensor PIR HC-SR501        │
                    └── Indicador LED / Relé       │
                                                   │
                                                   ▼
                                        Dashboard & Analytics
                                        (monitoramento em tempo real)
```

---

## Fluxo no Sistema

1. **Leitura dos Sensores**: O ESP32 realiza leituras contínuas do sensor PIR (presença) e a cada 2 segundos do sensor DHT22 (temperatura/umidade).
2. **Avaliação da Regra Local**: O firmware verifica se a sala está ocupada ou se a temperatura está fora da faixa de eficiência (`temp < 24°C`). Aciona ou desativa o atuador (LED/Relé) localmente.
3. **Envio da Telemetria**: O dispositivo formata o payload JSON e dispara uma requisição `POST /api/v1/telemetry` para o Backend.
4. **Validação e Persistência**: O Spring Boot valida os dados, calcula métricas acumuladas e atualiza a entidade da sala no PostgreSQL.
5. **Autenticação do Usuário**: O operador faz login no aplicativo Flutter, obtendo o token JWT do Keycloak.
6. **Consumo dos Dados**: O App consulta `GET /api/v1/dashboard/summary` e `GET /api/v1/rooms` exibindo o status em tempo real.
7. **Atuação Remota**: O operador pode alterar manualmente o status ou configuração da sala através de `PATCH /api/v1/rooms/{id}/status`.

---

## Modelo de Dados

O banco PostgreSQL é estruturado para suportar o cadastro de salas, telemetria temporal e auditoria de estado.

### Entidades Principais

| Entidade | Descrição | Campos Chave |
|---|---|---|
| `Room` | Cadastro dos ambientes monitorados | `id` (UUID), `name`, `code`, `capacity`, `status`, `createdAt`, `updatedAt` |
| `DeviceTelemetry` | Registro histórico de leituras ambientais enviadas pelo ESP32 | `id` (UUID), `roomId`, `temperature`, `humidity`, `heatIndex`, `occupied`, `timestamp` |
| `RoomOccupancyStatus` | Enumeração dos estados possíveis de um ambiente | `DISPONIVEL`, `OCUPADA`, `MANUTENCAO`, `ALERTA_DESPERDICIO` |

---

## Endpoints da API

Base path: `/api/v1`

### Autenticação & Perfil (`/auth`)
| Método | Endpoint | Descrição | Auth |
|---|---|---|:---:|
| `GET` | `/auth/config` | Retorna as configurações públicas do Keycloak (realm, auth-server) | ❌ |
| `GET` | `/auth/me` | Retorna informações do usuário logado e suas permissões (roles) | ✅ |
| `GET` | `/auth/logout-url` | Retorna a URL para encerramento de sessão no Keycloak | ✅ |

### Gestão de Salas (`/rooms`)
| Método | Endpoint | Descrição | Auth |
|---|---|---|:---:|
| `GET` | `/rooms` | Lista todas as salas cadastradas | ✅ |
| `POST` | `/rooms` | Cadastra uma nova sala | ✅ |
| `GET` | `/rooms/{id}` | Retorna os detalhes de uma sala específica por UUID | ✅ |
| `PUT` | `/rooms/{id}` | Atualiza dados cadastrais da sala | ✅ |
| `PATCH` | `/rooms/{id}/status` | Atualiza pontualmente o status de ocupação da sala | ✅ |
| `DELETE` | `/rooms/{id}` | Remove uma sala do sistema | ✅ |

### Telemetria & Dashboard (`/telemetry` e `/dashboard`)
| Método | Endpoint | Descrição | Auth |
|---|---|---|:---:|
| `POST` | `/telemetry` | Processa e armazena pacote de telemetria vindo do ESP32 | ✅ |
| `GET` | `/dashboard/summary` | Retorna o resumo consolidado de ocupação e alertas de desperdício | ✅ |

---

## Mapeamento de Hardware (ESP32)

| Componente | Tipo | Pino GPIO por Padrão | Função |
|---|---|---|---|
| **DHT22** | Entrada (Digital/1-Wire) | `GPIO 4` | Leitura de temperatura (°C) e umidade relativa (%) |
| **HC-SR501** | Entrada (Digital) | `GPIO 15` | Detecção PIR de movimento/presença humana |
| **LED / Relé** | Saída (Digital) | `GPIO 2` | Atuador de sinalização ou acionamento de carga |

---

## Configuração e Execução Local

### Pré-requisitos

- **Java 21 (JDK)**
- **Apache Maven 3.9+**
- **Docker** & **Docker Compose**
- **Flutter SDK 3.x**
- **ESP-IDF v5.x** (para gravação do firmware)

### 1. Inicializar Infraestrutura Docker (PostgreSQL)

Na raiz do repositório, execute:

```bash
docker-compose up -d
docker-compose ps
```

O banco PostgreSQL estará ativo na porta `5432` (banco: `energyguard`, usuário: `postgres`, senha: `postgres`).

### 2. Configuração e Execução do Backend

Navegue até o diretório `backend` e execute:

```bash
cd backend
./mvnw spring-boot:run
```

A aplicação estará acessível em `http://localhost:8081`.

### 3. Compilação e Gravação do Firmware ESP32

Conecte a placa ESP32 ao computador via USB e rode o script automatizado:

```bash
cd firmware
./run.sh /dev/ttyUSB0
```

*Caso esteja em ambiente Windows, substitua `/dev/ttyUSB0` pela porta COM correspondente (ex: `COM3`).*

### 4. Execução do Aplicativo Mobile

Em outro terminal, acesse a pasta `mobile`:

```bash
cd mobile
flutter pub get
flutter run
```

---

## Testes de Integração e API

Você pode testar as rotas da API REST via `curl` ou Postman:

### Teste de Health / Dashboard Summary

```bash
curl -X GET http://localhost:8081/api/v1/dashboard/summary \
  -H "Authorization: Bearer <SEU_TOKEN_JWT>"
```

### Simulação de Envio de Telemetria (ESP32 -> Backend)

```bash
curl -X POST http://localhost:8081/api/v1/telemetry \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <SEU_TOKEN_JWT>" \
  -d '{
    "roomId": "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
    "temperature": 25.5,
    "humidity": 60.0,
    "occupied": true
  }'
```

---

## Status de Desenvolvimento

Progresso atual: **95%**

### Concluído

- [x] Driver de firmware C para sensor DHT22 com cálculo de sensação térmica
- [x] Driver de firmware C para sensor PIR HC-SR501 com debouncing
- [x] Loop de tarefas FreeRTOS no ESP32 com atuador LED integrado
- [x] API Spring Boot 3.3 com suporte a Java 21 LTS
- [x] Entidades JPA e Repositórios para `Room` e `DeviceTelemetry`
- [x] Integração do Spring Security com OAuth2 Resource Server (Keycloak JWT)
- [x] Endpoints de Gestão de Salas (`RoomController`)
- [x] Endpoints de Telemetria e Dashboard (`TelemetryController`, `DashboardController`)
- [x] Endpoints de Perfil e Autenticação (`AuthController`)
- [x] Aplicativo Mobile em Flutter com suporte a login OIDC e navegação em abas
- [x] Telas de Dashboard, Lista de Salas e Formulário de Cadastro no App Mobile
- [x] `docker-compose.yml` pré-configurado com PostgreSQL 16

### Pendente

- [ ] Suporte a gravação Over-The-Air (OTA) no firmware ESP32
- [ ] Integração com broker MQTT (Mosquitto) para telemetria em alta frequência

---

## Decisões de Arquitetura

- **FreeRTOS para Multitasking no ESP32**: Garante que a leitura do sensor de movimento (PIR) seja tratada sem bloquear o loop de leitura do DHT22.
- **Validação de JWT via Keycloak**: Desacopla a gestão de usuários da aplicação principal. O backend atua como Resource Server validando as assinaturas dos tokens.
- **Resiliência Local no Firmware**: Caso a conexão de rede oscile, o firmware continua executando a regra de atuação local (controle do LED/Relé) com base na presença e temperatura.
- **Flutter para Multiplataforma**: Permite publicar o mesmo código-fonte para Android, iOS e Web sem duplicação de esforço UI.

---

## Estrutura do Repositório

```text
energy-guard/
├── backend/                  # API Rest em Spring Boot 3 (Java 21)
│   ├── src/main/java/        # Controllers, Services, DTOs, Entities, Security
│   ├── src/main/resources/   # Configurações (application.yaml)
│   └── pom.xml               # Dependências Maven
├── firmware/                 # Código C para ESP32 (ESP-IDF)
│   ├── main/                 # Módulos (main.c, dht22_sensor, pir_sensor, led_indicator)
│   ├── CMakeLists.txt        # Configuração do CMake
│   └── run.sh                # Script de compilação e gravação serial
├── mobile/                   # App Mobile em Flutter (Dart)
│   ├── lib/                  # Telas (Screens), Serviços (Services), Modelos (Models)
│   └── pubspec.yaml          # Dependências do Flutter
├── docs/                     # Documentação complementar do projeto
├── docker-compose.yml        # Orquestração do PostgreSQL
└── README.md                 # Documentação principal do repositório
```

---

## Licença

Este projeto é disponibilizado sob a licença **MIT**. Consulte o arquivo `LICENSE` para mais detalhes.

---

<p align="center">
  <i>EnergyGuard — Eficiência Energética Inteligente da Borda à Nuvem.</i>
</p>

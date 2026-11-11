# Energy Guard — Aplicativo Mobile (Flutter)

Aplicativo móvel do projeto **Energy Guard**, desenvolvido em Flutter para supervisão em tempo real de ocupação e detecção de desperdício energético de sistemas de ar-condicionado em ambientes climatizados.

---

## 📋 Pré-requisitos

Antes de iniciar, certifique-se de ter instalado em sua máquina:

* **Flutter SDK** (versão 3.x ou superior) — [Guia de Instalação](https://docs.flutter.dev/get-started/install)
* **Dart SDK** (versão 3.x ou superior)
* Um ambiente de execução:
  * **Google Chrome** (mais rápido para testes e bancas)
  * **Xcode** / **Simulador iOS** (para macOS)
  * **Android Studio** / **Emulador Android** ou celular físico conectado via USB com depuração ativada.

Para verificar se o seu ambiente Flutter está configurado corretamente, execute no terminal:
```bash
flutter doctor
```

---

## 🚀 Como Executar o Aplicativo

Entre na pasta do projeto mobile:
```bash
cd mobile
```

Baixe as dependências do projeto:
```bash
flutter pub get
```

Agora, escolha uma das opções abaixo para executar:

### 1. No Google Chrome (Mais rápido para testes / apresentações ⚡)
Executa imediatamente no navegador:
```bash
flutter run -d chrome
```
> **Dica de Visualização Mobile:** Com a janela do Chrome aberta, pressione `F12` (ou `Cmd + Option + I` no Mac) e clique no ícone **Toggle Device Toolbar** (ícone de celular/tablet) para visualizar a proporção exata de um smartphone.

---

### 2. No macOS (Aplicativo Desktop Nativo 💻)
```bash
flutter run -d macos
```

---

### 3. No Emulador ou Celular Físico 📱
* **Listar dispositivos conectados:**
  ```bash
  flutter devices
  ```
* **Executar no dispositivo desejado:**
  ```bash
  flutter run
  ```
  *(Se tiver mais de um dispositivo conectado, use `flutter run -d <id-do-dispositivo>`)*

---

## ⚙️ Conectando ao Backend (Configuração de IP)

O aplicativo conta com configuração dinâmica de rede para facilitar a troca de ambiente sem precisar recompilar código:

1. Na **tela de Login**, clique no **ícone de engrenagem ⚙️** no canto superior direito.
2. Defina o IP correspondente ao seu ambiente:
   * **Chrome ou macOS Desktop:** use `localhost`.
   * **Emulador Android:** use `10.0.2.2` (endereço de loopback do emulador para o host).
   * **Celular Físico:** insira o IP da sua máquina na rede local Wi-Fi (ex: `192.168.1.15`).
3. Clique em **Salvar**.

---

## 🔑 Acesso e Credenciais de Demonstração

Para facilitar testes e apresentações, o aplicativo já inicia com credenciais de teste pré-preenchidas:

* **E-mail / Usuário:** `admin@energyguard.com`
* **Senha:** `123456`

> **Resiliência para Apresentação (Modo Offline/Fallback):**  
> Caso o Keycloak ou o Backend não estejam rodando no momento da execução, o aplicativo realiza login em **Modo Demonstração** automaticamente, permitindo navegar pelas telas de Dashboard e Salas sem travamentos.

---

## 📱 Principais Funcionalidades

* **Autenticação Flexível:** Suporte a token OAuth2/Keycloak com fallback seguro de demonstração.
* **Dashboard em Tempo Real ("Ao Vivo"):**
  * Atualização periódica automática (*polling* a cada 4 segundos).
  * **Banner Dinâmico de Alerta de Desperdício:** Destacado em vermelho quando há ar-condicionado operando em sala vazia.
  * Cálculo em tempo real do **custo estimado por hora (R$/h)** e **potência ociosa (kWh/h)**.
  * Cards de indicadores-chave (Salas Ocupadas, Salas em Alerta, Ar Ligado Sem Pessoas).
* **Gestão e Monitoramento de Salas:**
  * Visualização da temperatura medida pelos sensores vs. temperatura alvo.
  * Status da sala (`Ocupada`, `Vazia` ou `Desperdício Detectado`).
  * CRUD completo de salas (Cadastro, Edição e Exclusão).
* **Configuração de Conectividade:** Alteração dinâmica do host/IP da API REST.

---

## 📂 Estrutura de Pastas

```text
mobile/
├── lib/
│   ├── models/
│   │   ├── dashboard_summary_model.dart  # Modelos de dados do resumo e KPIs
│   │   └── room_model.dart               # Modelo de dados da Sala e status
│   ├── screens/
│   │   ├── dashboard_screen.dart         # Tela principal de alertas e métricas
│   │   ├── login_screen.dart             # Tela de login e config de servidor
│   │   ├── main_navigation_screen.dart   # Barra de navegação inferior
│   │   ├── room_form_screen.dart         # Formulário de criação/edição de sala
│   │   └── room_list_screen.dart         # Listagem e monitoramento das salas
│   ├── services/
│   │   ├── api_config.dart               # Centralização de URLs e IP do backend
│   │   ├── auth_service.dart             # Serviço de autenticação e sessão
│   │   ├── dashboard_service.dart        # Consumo da rota /dashboard/summary
│   │   └── room_service.dart             # Consumo da rota /rooms (CRUD)
│   └── main.dart                         # Ponto de entrada do aplicativo Flutter
├── assets/images/                        # Imagens e logo da aplicação
└── pubspec.yaml                          # Dependências e metadados do projeto
```

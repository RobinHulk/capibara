# Capibara — memory.md

> Este arquivo registra o contexto do projeto para sessões futuras do agente.

---

## Origem e estado atual

| Campo             | Valor                                                                 |
|-------------------|-----------------------------------------------------------------------|
| Fork de           | `Timoteohss/capy` (repo upstream, Apache 2.0)                        |
| Fork atual        | `RobinHulk/capibara` — https://github.com/RobinHulk/capibara        |
| Upstream original | https://github.com/Timoteohss/capy                                   |
| Licença           | Apache 2.0                                                            |
| Linguagem primária| Dart (Flutter)                                                        |
| Status            | **Abandonado pelo dono original.** Continuação pelo fork atual.      |
| Responsável atual | RobinHulk                                                             |
| Último push       | 2026-11-09                                                            |
| Status da suíte   | 2.125 testes passando (car app: 1042, capy_ui: 364, core: 284, companion: 435) |
| Branch default    | `main`                                                                |
| Schema Room       | v35 → `databases/geely_telemetry.db`                                 |
| Flutter requerido | 3.44.6                                                                |
| Android minSdk    | 28 (arm64 apenas)                                                     |

---

## O que o projeto faz

Capibara é um app de telemetria de bateria e energia para **veículos elétricos Geely** com head unit **Android Automotive (Flyme Auto)**. Registra viagens, carregamentos e histórico de sinais CAN, e exibe tudo no celular ao lado do carro.

Dois apps, dois packages Dart compartilhados:

| App | Local | Roda em | Função |
|-----|-------|---------|--------|
| Car app | raiz do repo | Head unit AAOS | Coleta sinais VHAL/Roadcast, grava no Room, serve ao celular |
| Companion | `apps/companion/` | Android / iOS | Pareia via código de 6 dígitos, pull via Wi-Fi, sync Supabase |

---

## Arquitetura em camadas

```
Flutter UI  <->  Pigeon bridge  <->  Kotlin/Android
    |                                     |
packages/capy_ui          android/.../telemetry/
packages/telemetry_core   android/.../profile/  (Layer 0)
```

- **Flutter** — UI, navegação, estado de apresentação, gráficos, filtros.
- **Kotlin/Android** — acesso ao veículo, permissões AAOS, serviços de lifecycle, Room.
- **Pigeon** (`pigeons/telemetry_wire.dart`) — ponte tipada Dart <-> Kotlin.
- **Layer 0** (`profile/`) — `VehicleProfile`, `GeelyProfile`, constantes VHAL. Código acima não referencia hex VHAL direto.

---

## Módulos e paths principais

| Módulo | Path | O que é |
|--------|------|---------|
| Design system | `packages/capy_ui/` | Componentes e tokens de UI. Ver `packages/capy_ui/DESIGN.md` |
| Telemetry core | `packages/telemetry_core/` | Encoding de track, física, protocolo de sync |
| Companion app | `apps/companion/` | App Flutter para celular |
| Perfil do veículo | `android/app/src/main/kotlin/com/timhss/capyenergy/profile/` | `GeelyProfile`, `GeelyDeclarations`, `GeelyProperties` |
| Control plane | `android/.../telemetry/control/` | `PreferenceControlSync`, lê `preference_desired`, reporta via `preference_reported` |
| Pigeon wire | `pigeons/telemetry_wire.dart` | Schema da bridge Flutter <-> Kotlin |
| Mock data | `lib/core/mock_telemetry_data.dart` | Dados sintéticos para rodar sem carro |
| Scripts | `scripts/` | `install.sh`, `build_cloud_sync_test.sh`, `create_release_manifest.sh` |
| Supabase | `supabase/` | Migrations, edge functions, RLS, testes SQL |
| ADRs | `docs/adr/` | Decisões de arquitetura — ler antes de modificar padrões core |
| Release notes | `release_notes/current.json` | PT, EN, RU — atualizar após features/fixes |

---

## Fluxo de dados ao vivo

```
CAN bus -> Roadcast (60 Hz) -> libroadcast_client.so -> in-RAM cache -> Flutter UI
                                                                        (Trip / Charge screens)
CarPropertyManager -> EventChannel -> Flutter (vehicle speed e VHAL props)
```

**Roadcast não está no repo** — binários externos que devem ser compilados de:
- https://github.com/Timoteohss/roadcast
- Instalar com: `scripts/update_roadcast_client.sh --roadcast-root <dir>`
- Sem eles: build Android falha no CMake.

---

## Storage (Room)

- Schema v35, arquivo `databases/geely_telemetry.db`
- Tabelas: `session`, `interval`, `sample` (removido após schema 41), `telemetry_events`, battery cycles, costs, places, trip segments, preferences, journeys, sync cursors.
- Retenção: frames/events expiram em chunks de 2.000 rows; buckets por minuto e agregados de sessão sobrevivem.

---

## Cloud sync (Supabase — opcional)

- Sem credenciais: tudo local, nada sai do dispositivo.
- Gate de sync: **ligado por padrão** em ambos os apps.
- Script de teste end-to-end: `scripts/build_cloud_sync_test.sh` (recusa build se gate está false).
- Configurar: `android/local.properties` (car app) e `.env` (companion, template em `.env.example`).

### Sync Lanes (ADR-0012)

| Lane | Quem escreve | Regra de conflito |
|------|-------------|-------------------|
| Measurement | Apenas o carro | Sem conflito; carro faz upload direto |
| Annotation | Qualquer device | Last-writer-wins |
| Control | Telefone propõe, carro decide | Nunca merge; desired -> reported |

---

## Comandos essenciais

```bash
# Build car app
flutter pub get
flutter build apk --release

# Instalar no head unit
scripts/install.sh
scripts/install.sh --device 10.10.10.117:5555

# Rodar UI mock (sem carro)
flutter run -d chrome --dart-define=CAPY_MOCK_TELEMETRY=true

# Build companion
cd apps/companion && flutter pub get
flutter run --dart-define-from-file=.env

# Testes Flutter
flutter test --concurrency 6
(cd packages/capy_ui && flutter test --concurrency 6) & \
(cd packages/telemetry_core && flutter test) & \
(cd apps/companion && flutter test) & wait

# Testes Android
(cd android && ./gradlew testDebugUnitTest)

# Atualizar bridge Pigeon
dart run pigeon --input pigeons/telemetry_wire.dart
dart format lib test packages

# Analise
dart format lib test packages apps
flutter analyze lib test packages apps

# Supabase
supabase db push
supabase functions deploy device-pairing
supabase functions deploy privacy
```

---

## Regras de segurança e hardware

- **Nunca instalar** com `pm uninstall` ou em `/system/priv-app`.
- **Sempre usar** `scripts/install.sh` para instalar APK.
- **Antes de `connectedDebugAndroidTest`**: fazer pull do banco:
  ```bash
  python3 -m tool.telemetry_report pull dbpull/<nome>.db
  ```
- **Builds locais** levam suffix `-debug`; o `AppUpdateManager` recusa auto-update em builds com esse suffix.
- **Write verification**: controles que escrevem no veículo (ex: `setChargingAmperage`) devem mostrar o valor confirmado pelo hardware, nunca estado otimista.

---

## Assinatura e versionamento

- `version:` em `pubspec.yaml` (`X.Y.Z+B`) é a fonte única da verdade.
- Chave: AOSP test platform key (`platform`, senha `android`), em `refs/aosp-security/`.
- Gerar keystore: `scripts/generate_platform_keystore.sh`.
- Release pipeline: `.github/workflows/release.yml` ou `scripts/release_manual.sh`.

---

## Domínio — termos canônicos

| Termo | Definição curta |
|-------|----------------|
| Session | Bloco de atividade: Trip, Charge ou Parked |
| Interval | Agregação de 1 minuto dentro de uma sessão |
| Measurement | Valor + unidade + estado de validade |
| Annotation | Metadado editável por qualquer device (places, costs) |
| Control | Configuração que o telefone propõe e o carro decide |
| Layer 0 | Camada de hardware: VehicleProfile, GeelyProfile |
| Pigeon Surface | Bridge Flutter <-> Kotlin via schema tipado |
| Live Stream | Push BLE do carro para o telefone (0xCB02) |
| Measured Trip | Viagem com energia CAN + buckets + distância acima do mínimo |
| InsightPlace | Localização nomeada com centro e raio configurável |
| Named Route | Par ordenado de dois InsightPlaces + viagens entre eles |

---

## Contexto de continuação

O projeto foi **abandonado pelo dono original** (`Timoteohss`). O fork `RobinHulk/capibara` é o workspace ativo de continuação. O código está completo e funcional:
- Análise estática limpa com exclusão de pastas de build (`analysis_options.yaml`).
- 2.125 testes automatizados validados e passando em todos os 4 módulos.
- Interface legada V1 e widgets obsoletos purgados; o app abre diretamente no `AppShellV2`.
- Telas de diagnóstico preservadas movidas para `lib/screens_v2/` (`charging_session_display.dart`, `roadcast_trace_screen.dart`, `sensor_lab_screen.dart`).
- Correção ortográfica de `settingsWiping` sincronizada em PT (`app_pt.arb` e `app_localizations_pt.dart`).
- Notas de release em `release_notes/current.json` alinhadas e validadas (12 itens por idioma).
- Binários nativos Roadcast (`libroadcast_client.so` e `roadcastd`, canal `edge`) instalados localmente.
- Keystore pública AOSP gerada em `refs/aosp-security/platform.jks` (SHA-256 verificado).
- Build release do APK (`flutter build apk --release` -> `app-release.apk`) validado com sucesso.
- Configuração de build Android: `kotlin.incremental=false` em `android/gradle.properties` para compilação Windows multi-drive.
- Servidor web mock da nova interface V2 validado em `http://localhost:8080`.

Faltam para ambiente físico / produção:
1. Supabase credentials (`android/local.properties`, `apps/companion/.env`).
2. Validar instalação em veículo físico com `scripts/install.sh`.
3. Ver issues abertas no upstream (`Timoteohss/capy`) para o que precisa de dono.
4. Atualizar `release_notes/current.json` após qualquer feature ou fix.

Ler `docs/adr/` antes de mudar padrões de arquitetura. Ler `packages/capy_ui/DESIGN.md` antes de mudar UI.


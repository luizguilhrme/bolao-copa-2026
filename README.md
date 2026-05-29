# Bolão Copa 2026

App Flutter para bolão da Copa do Mundo 2026. Usuários registram palpites de placar; um admin insere os resultados reais e o app calcula e classifica os jogadores por pontuação. Backend: Firebase (Auth + Firestore).

## Configuração do ambiente

### Pré-requisitos

- Flutter SDK
- Node.js LTS (v22+)
- Firebase CLI: `npm install -g firebase-tools`
- FlutterFire CLI: `dart pub global activate flutterfire_cli`

### Credenciais Firebase (obrigatório)

Os arquivos `google-services.json` e `lib/firebase_options.dart` **não estão no repositório** (contêm API keys — repo público). É necessário gerá-los localmente antes de rodar o app:

1. Faça login no Firebase CLI:
   ```bash
   firebase login
   ```

2. Gere os arquivos de configuração apontando para o projeto `bolaodasoci2026`:
   ```bash
   flutterfire configure --project=bolaodasoci2026
   ```
   Isso gera automaticamente `lib/firebase_options.dart` e `android/app/google-services.json`.

### Instalação e execução

```bash
flutter pub get
flutter run
```

## Comandos úteis

```bash
flutter pub get          # instalar dependências
flutter run              # rodar no dispositivo/emulador conectado
flutter analyze          # análise estática
flutter test             # rodar todos os testes
flutter build apk        # gerar APK Android
flutter build appbundle  # gerar AAB para Play Store
flutter build web        # gerar build web/PWA
```

### Deploy da PWA

```bash
flutter build web --release
firebase deploy --only hosting --project bolaodasoci2026
```

URL de produção: https://bolaodasoci2026.web.app

## Popular os jogos no Firestore

Abrir o app → drawer → ADMIN → Outras Definições → Popular Jogos.  
Escolher **Produção** (`jogos.json`) ou **Teste** (`jogos_teste.json`, datas deslocadas −25 dias com resultados pré-preenchidos).

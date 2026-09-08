# Astra Nutrition OS — native mobile clients

В репозитории добавлены два независимых нативных клиента:

- `ios/AstraMobile` — SwiftUI, iOS 17+
- `android` — Kotlin + Jetpack Compose, Android 8.0+

Оба клиента используют существующий FastAPI REST API под `/api/v1` и не требуют изменений backend.

## API base URL

По умолчанию:

- Production/server API: `http://204.168.255.69:8787/api/v1`
- iOS Simulator/local development: `http://127.0.0.1:8787/api/v1`
- Android Emulator/local development: `http://10.0.2.2:8787/api/v1`

Текущий сервер использует HTTP, поэтому Android разрешает cleartext-трафик, а iOS — HTTP через ATS-настройку. Для production обязательно переведите API на HTTPS.

## iOS

Откройте `ios/AstraMobile.xcodeproj` в Xcode, выберите signing team и запустите target `AstraMobile`.

Настройка адреса API доступна в приложении: `Профиль → Адрес API`.

## Android

Откройте папку `mobile/android` в Android Studio и запустите configuration `app`. Если Gradle установлен глобально, сборка выполняется так:

```bash
gradle :app:assembleDebug
```

В приложении адрес API также меняется через `Ещё → Адрес API`.

## Реализованный мобильный контур

- вход и регистрация;
- сохранение JWT между запусками;
- обзор с основными показателями и последним замером;
- дневник питания: просмотр, добавление продукта/рецепта и удаление записи;
- каталог продуктов и рецептов с деталями;
- прогресс: просмотр и добавление замера;
- тренировки: просмотр планов и журнала, отметка плана выполненным;
- выход из аккаунта и смена API URL.

Редактирование общих справочников, администрирование, модерация и trainer/client workspace остаются в существующем веб-интерфейсе, где для них уже есть полноценные desktop-формы.

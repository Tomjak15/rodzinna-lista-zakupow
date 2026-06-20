# Rodzinna Lista Zakupów

Flutterowa aplikacja rodzinnej listy zakupów działająca na Androidzie, iOS oraz jako PWA w przeglądarce. Aplikacja jest offline-first: zapisuje dane lokalnie na urządzeniu, pokazuje elementy oczekujące na synchronizację i wysyła zmiany do własnego serwera po odzyskaniu internetu.

## Czy potrzebny jest serwer?

Do samego działania na jednym urządzeniu nie. Aplikacja zapisuje dane lokalnie.

Do wspólnej listy między kilkoma telefonami potrzebny jest serwer w internecie. W tej wersji nie ma Supabase. Jest własny backend:

- Node.js + Express
- SQLite
- automatyczne tworzenie bazy i tabel przy starcie
- gotowy do wrzucenia na Replit

## Technologia

- Flutter: Android APK, iOS, Web/PWA.
- Własny REST API: synchronizacja danych między członkami rodziny.
- SQLite na serwerze: wspólna baza rodziny.
- SharedPreferences w aplikacji: lokalny zapis offline.
- Zasada konfliktów: ostatnia zmiana wygrywa na podstawie `updatedAt` / `updated_at`.
- Android: minimalnie API 23, compile SDK 36, NDK 27.0.12077973.

## Struktura

```text
lib/
  app/                 Stan aplikacji, motyw i AppScope
  config/              Konfiguracja serwera przez --dart-define=SERVER_URL
  data/                Lokalny magazyn i synchronizacja z REST API
  models/              Modele: rodziny, członkowie, produkty, obiady, przepisy, kalendarze
  screens/             Ekrany: start, lista zakupów, obiady, kalendarz, rodzina, ustawienia
server/
  index.js             Serwer Node/Express
  package.json         Zależności serwera
  README.md            Instrukcja Replit
android/               Konfiguracja APK
ios/                   Konfiguracja iOS
web/                   Manifest i konfiguracja PWA
```

## Funkcje

- Ekran startowy: `Utwórz rodzinę` albo `Dołącz do rodziny`.
- Kod rodziny do kopiowania i wysyłania innym osobom.
- Wspólna lista zakupów dla osób z tym samym kodem rodziny.
- Dołączanie po kodzie jest potwierdzane przez serwer: aplikacja najpierw pobiera prawdziwą rodzinę po kodzie, zapisuje członka pod jej `familyId`, a dopiero potem wpuszcza użytkownika do aplikacji.
- Lista zakupów w prostym stylu Listonic: szybkie wpisywanie i podpowiedzi produktów.
- Dodawanie, edycja, usuwanie, zaznaczanie i odznaczanie produktów.
- Automatyczne łączenie tego samego produktu z tą samą jednostką.
- Zakładka `Obiady` z przepisami, składnikami i porcjami bazowymi.
- Składniki przepisu są wpisywane w osobnych polach: składnik, ilość, jednostka.
- Podprzepisy/dodatki przypisane do głównego obiadu.
- Dodawanie do listy zakupów: tylko główny przepis, wybrane dodatki albo wszystkie dodatki.
- Proporcjonalne przeliczanie składników według liczby porcji.
- Scalanie powtarzających się składników przy dodawaniu do listy.
- Zakładka `Kalendarz`: planowanie posiłków na konkretny dzień.
- Zaplanowanie posiłku automatycznie przelicza porcje i dodaje składniki do listy zakupów.
- Wydarzenia rodzinne: wpisy dla całej rodziny albo konkretnej osoby.
- Twórca rodziny może dodać dodatkowe osoby do kalendarza.
- Status `oczekuje na synchronizację` przy elementach zapisanych lokalnie.
- Stała synchronizacja w tle co kilka sekund, gdy aplikacja ma internet i skonfigurowany serwer.

## Uruchomienie serwera lokalnie

```bash
cd server
npm install
npm start
```

Serwer działa pod:

```text
http://localhost:3000
```

Test:

```text
http://localhost:3000/api/health
```

Baza SQLite tworzy się automatycznie w `server/data/rodzinna_lista.sqlite`.

## Replit

Repozytorium ma root `.replit`, więc można importować cały projekt z GitHuba. Replit uruchomi tylko backend z katalogu `server`.

Szybki import publicznego repo:

```text
https://replit.com/github.com/Tomjak15/rodzinna-lista-zakupow
```

Import ręczny:

1. Otwórz `https://replit.com/import`.
2. Wybierz `GitHub`.
3. Wklej albo wybierz repo:

```text
https://github.com/Tomjak15/rodzinna-lista-zakupow
```

4. Kliknij `Import`.
5. Po imporcie kliknij `Run`.

Replit wykona:

```bash
cd server && npm install && npm start
```

Serwer powinien pokazać endpoint API. Sprawdź:

```text
https://twoj-replit-url/api/health
```

Wklej adres bez `/api/health` w aplikacji: `Ustawienia > Adres serwera`, np.:

```text
https://rodzinna-lista-zakupow.twoj-login.replit.app
```

Możesz też wbudować adres w APK/PWA przez `--dart-define=SERVER_URL=...`, ale nie jest to konieczne, bo adres można zmienić w ustawieniach aplikacji.

## Render

Projekt ma gotowy plik `render.yaml` w katalogu głównym. Konfiguracja tworzy web service Node.js dla katalogu `server`, ustawia health check `/api/health` i podpina persistent disk pod SQLite.

Ważne: SQLite na Render wymaga persistent disk. Według dokumentacji Render dyski są dostępne dla płatnych usług, a zwykły filesystem usługi bez dysku jest ulotny po restartach/deployach. Dlatego `render.yaml` używa planu `starter` i dysku `/var/data`.

Deploy przez Dashboard:

1. Wypchnij ten projekt do repozytorium GitHub/GitLab/Bitbucket.
2. Otwórz Render Dashboard.
3. Wybierz `New > Blueprint`.
4. Wskaż repozytorium z tym projektem.
5. Render odczyta `render.yaml`.
6. Kliknij `Apply`.
7. Po deployu otwórz adres:

```text
https://twoja-usluga.onrender.com/api/health
```

8. W APK wejdź w `Ustawienia > Adres serwera` i wpisz adres Render, np.:

```text
https://rodzinna-lista-zakupow-api.onrender.com
```

## Uruchomienie aplikacji

Bez synchronizacji, tylko lokalnie:

```bash
flutter pub get
flutter run -d chrome
```

Z lokalnym serwerem:

```bash
flutter run -d chrome \
  --dart-define=SERVER_URL=http://localhost:3000
```

Z serwerem Replit:

```bash
flutter run -d chrome \
  --dart-define=SERVER_URL=https://twoj-serwer.replit.app
```

Jeśli uruchomisz aplikację bez `SERVER_URL`, wejdź w `Ustawienia > Adres serwera` i wpisz tam adres Replit.

Na Androidzie, jeżeli używasz serwera lokalnego z telefonu fizycznego, `localhost` oznacza telefon, nie komputer. Wtedy użyj adresu IP komputera w sieci Wi-Fi albo publicznego adresu Replit.

## APK na Androida

Debug APK:

```bash
flutter build apk --debug
```

Release APK:

```bash
flutter build apk --release
```

Release APK jest podpisywane lokalnym kluczem z `android/key.properties` i `android/app/rodzinna-lista-release.jks`. Tych plików nie wrzucaj do GitHub ani ZIP, ale zachowaj je na komputerze, bo ten sam klucz jest potrzebny do aktualizacji aplikacji na telefonie.

Po instalacji APK wpisz adres serwera w `Ustawienia > Adres serwera`. Jeżeli wolisz wbudować adres na stałe, dodaj `--dart-define=SERVER_URL=https://twoj-serwer.onrender.com`.

Plik APK będzie w:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## iOS

iOS wymaga macOS, Xcode i konta Apple Developer do publikacji.

Uruchomienie na podłączonym iPhonie:

```bash
flutter run -d ios \
  --dart-define=SERVER_URL=https://twoj-serwer.replit.app
```

Build release:

```bash
flutter build ios --release \
  --dart-define=SERVER_URL=https://twoj-serwer.replit.app
```

Publikacja:

1. Otwórz `ios/Runner.xcworkspace` w Xcode.
2. Ustaw team, bundle identifier i signing.
3. Wybierz `Product > Archive`.
4. Wyślij archiwum do TestFlight albo App Store.

## PWA

Build web/PWA:

```bash
flutter build web --release --pwa-strategy=offline-first \
  --dart-define=SERVER_URL=https://twoj-serwer.replit.app
```

Pliki PWA będą w:

```text
build/web
```

Lokalny podgląd po buildzie:

```bash
cd build/web
python -m http.server 8080
```

Potem otwórz `http://localhost:8080`. Przeglądarka pokaże opcję instalacji PWA, gdy strona będzie serwowana przez HTTPS albo lokalnie przez `localhost`.

## Dane i synchronizacja

Serwer tworzy tabele:

- `families`
- `members`
- `shopping_items`
- `meals`
- `recipes`
- `recipe_ingredients`

Każdy rekord ma `id`, `family_id`, `created_at`, `updated_at`, `created_by` oraz `is_deleted`. Podprzepisy są zapisane w tabeli `recipes` przez pole `parent_recipe_id`.

SQLite na Replit wystarczy do prototypu i małej rodzinnej aplikacji. Przy większej liczbie użytkowników warto później przenieść serwer na hosting z trwałym dyskiem albo PostgreSQL.

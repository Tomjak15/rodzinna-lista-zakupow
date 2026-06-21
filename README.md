# Rodzinna Lista Zakupów

Flutterowa aplikacja rodzinnej listy zakupów działająca na Androidzie, iOS oraz jako PWA w przeglądarce. Aplikacja jest offline-first: zapisuje dane lokalnie na urządzeniu, pokazuje elementy oczekujące na synchronizację i wysyła zmiany do własnego serwera po odzyskaniu internetu.

## Czy potrzebny jest serwer?

Do samego działania na jednym urządzeniu nie. Aplikacja zapisuje dane lokalnie.

Do wspólnej listy między kilkoma telefonami potrzebny jest serwer w internecie. W tej wersji nie ma Supabase. Jest własny backend:

- Node.js + Express
- SQLite
- automatyczne tworzenie bazy i tabel przy starcie
- Cloudflare Workers + D1, czyli darmowy backend w chmurze bez włączonego komputera
- lokalny wariant Node.js + SQLite do testów na komputerze

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
  README.md            Instrukcja lokalnego serwera Node
cloudflare-worker/
  src/index.js          Serverless API dla Cloudflare Workers
  migrations/           Schemat bazy D1
  scripts/              Deploy i eksport danych do D1
android/               Konfiguracja APK
ios/                   Konfiguracja iOS
web/                   Manifest i konfiguracja PWA
```

## Funkcje

- Ekran startowy: `Utwórz rodzinę` albo `Dołącz do rodziny`.
- Kod rodziny do kopiowania i wysyłania innym osobom.
- Wspólna lista zakupów dla osób z tym samym kodem rodziny.
- Dołączanie po kodzie jest potwierdzane przez serwer: aplikacja najpierw pobiera prawdziwą rodzinę po kodzie, zapisuje członka pod jej `familyId`, a dopiero potem wpuszcza użytkownika do aplikacji.
- Członek może opuścić rodzinę, a twórca rodziny może wyrzucić inne osoby.
- Lista zakupów w prostym stylu Listonic: duży boczny przycisk `+`, panel dodawania, podpowiedzi po wpisaniu tekstu oraz produkty z przepisów i historii listy.
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

## Cloudflare Workers + D1

To jest najlepsza darmowa ścieżka, gdy aplikacja ma synchronizować dane bez włączonego komputera.

Backend Cloudflare ma te same endpointy co lokalny serwer Node, ale:

- API działa jako Cloudflare Worker,
- baza działa jako Cloudflare D1,
- komputer nie musi być włączony,
- aktualna lokalna baza SQLite może zostać wyeksportowana i wgrana do D1.

Wymagane jest konto Cloudflare i logowanie przez Wrangler. Aktualnie wdrożony serwer:

```text
https://rodzinna-lista-zakupow-api.rodzinna-lista-zakupow-tomek.workers.dev
```

Deploy z katalogu głównego:

```powershell
.\cloudflare-worker\scripts\deploy-cloudflare.ps1
```

Skrypt:

1. instaluje narzędzia Cloudflare,
2. loguje do konta Cloudflare, jeśli trzeba,
3. tworzy bazę D1,
4. wgrywa schemat tabel,
5. eksportuje obecną lokalną bazę SQLite,
6. importuje dane do D1,
7. publikuje Workera,
8. buduje APK z adresem nowego serwera.

Po deployu adres serwera jest zapisany w:

```text
runtime/cloudflare-hosting.env
```

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

Z serwerem Cloudflare:

```bash
flutter run -d chrome \
  --dart-define=SERVER_URL=https://rodzinna-lista-zakupow-api.rodzinna-lista-zakupow-tomek.workers.dev
```

Jeśli uruchomisz aplikację bez `SERVER_URL`, aplikacja użyje domyślnego adresu Cloudflare z `lib/config/backend_config.dart`.

Na Androidzie, jeżeli używasz serwera lokalnego z telefonu fizycznego, `localhost` oznacza telefon, nie komputer. Wtedy użyj adresu IP komputera w sieci Wi-Fi albo publicznego adresu Cloudflare.

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

Release APK domyślnie łączy się z aktualnym serwerem Cloudflare. Jeżeli chcesz nadpisać adres, użyj:

```bash
flutter build apk --release \
  --dart-define=SERVER_URL=https://rodzinna-lista-zakupow-api.rodzinna-lista-zakupow-tomek.workers.dev
```

Plik APK będzie w:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## iOS

iOS wymaga macOS, Xcode i konta Apple Developer do publikacji.

Uruchomienie na podłączonym iPhonie:

```bash
flutter run -d ios \
  --dart-define=SERVER_URL=https://rodzinna-lista-zakupow-api.rodzinna-lista-zakupow-tomek.workers.dev
```

Build release:

```bash
flutter build ios --release \
  --dart-define=SERVER_URL=https://rodzinna-lista-zakupow-api.rodzinna-lista-zakupow-tomek.workers.dev
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
  --dart-define=SERVER_URL=https://rodzinna-lista-zakupow-api.rodzinna-lista-zakupow-tomek.workers.dev
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

Cloudflare Workers + D1 jest teraz głównym darmowym hostingiem dla synchronizacji. Lokalny serwer Node/SQLite zostaje jako tryb developerski i zapasowy.

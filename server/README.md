# Serwer Rodzinnej Listy Zakupów

To jest własny backend zamiast Supabase. Działa jako REST API w Node.js, Express i SQLite.

## Co robi serwer

- Tworzy bazę SQLite automatycznie przy starcie.
- Tworzy tabele: `families`, `members`, `shopping_items`, `meals`, `recipes`, `recipe_ingredients`, `meal_plans`, `calendar_events`, `favorite_products`, `receipts`.
- Udostępnia API dla aplikacji Flutter.
- Przy konflikcie zapisów stosuje zasadę: nowsze `updated_at` wygrywa.

## Uruchomienie lokalnie

```bash
npm install
npm start
```

Serwer działa domyślnie pod:

```text
http://localhost:3000
```

Test:

```text
http://localhost:3000/api/health
```

## Replit

1. Utwórz nowy Repl jako `Node.js`.
2. Wgraj zawartość katalogu `server`.
3. Uruchom:

```bash
npm install
npm start
```

4. Replit pokaże publiczny adres, np.:

```text
https://rodzinna-lista-zakupow.twoj-login.replit.app
```

5. Ten adres wpisz w aplikacji: `Ustawienia > Adres serwera`.

Możesz też podać adres przy buildzie Fluttera jako `SERVER_URL`.

## Build aplikacji z tym serwerem

```bash
flutter build apk --release \
  --dart-define=SERVER_URL=https://twoj-serwer.replit.app
```

PWA:

```bash
flutter build web --release --pwa-strategy=offline-first \
  --dart-define=SERVER_URL=https://twoj-serwer.replit.app
```

## Endpointy

- `GET /api/health`
- `GET /api/families/code/:code`
- `GET /api/:table?familyId=:familyId`
- `PUT /api/:table/:id`

Dozwolone wartości `table`:

- `families`
- `members`
- `shopping_items`
- `meals`
- `recipes`
- `recipe_ingredients`
- `meal_plans`
- `calendar_events`
- `favorite_products`
- `receipts`

## Ważne

SQLite na Replit jest najprostsze do startu i prototypu. Jeśli aplikacja ma być używana przez dużo rodzin, lepszy będzie później hosting z trwałym dyskiem albo PostgreSQL, np. Render, Railway, Fly.io albo VPS.

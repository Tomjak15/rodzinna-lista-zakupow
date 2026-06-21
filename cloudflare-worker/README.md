# Cloudflare Worker + D1

Ten katalog zawiera darmowy backend chmurowy dla aplikacji Rodzinna Lista Zakupow.

## Co to daje

- API dziala w Cloudflare Workers, wiec nie wymaga wlaczonego komputera.
- Baza dziala w Cloudflare D1, czyli SQLite w chmurze.
- Endpointy sa zgodne z aplikacja Flutter:
  - `GET /api/health`
  - `GET /api/families/code/:code`
  - `GET /api/:table?familyId=...`
  - `PUT /api/:table/:id`

## Deploy

Z katalogu glownego projektu:

```powershell
.\cloudflare-worker\scripts\deploy-cloudflare.ps1
```

Skrypt:

1. instaluje Wranglera,
2. loguje do Cloudflare, jesli trzeba,
3. tworzy baze D1,
4. wgrywa migracje tabel,
5. eksportuje obecna lokalna baze SQLite,
6. importuje dane do D1,
7. publikuje Workera,
8. buduje APK z nowym adresem serwera.

Po deployu nowy adres trafi do:

```text
runtime/cloudflare-hosting.env
```

Eksport danych trafia do:

```text
runtime/d1-data.sql
```

Nie wrzucaj `runtime/d1-data.sql` do publicznego repo, bo moze zawierac prywatne dane rodziny.

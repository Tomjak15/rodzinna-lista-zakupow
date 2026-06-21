param(
  [string]$DatabaseName = "rodzinna-lista-zakupow",
  [string]$OutputApk = "..\outputs\rodzinna-lista-zakupow-release.apk"
)

$ErrorActionPreference = "Stop"

$workerPath = Resolve-Path (Join-Path $PSScriptRoot "..")
$repoRoot = Resolve-Path (Join-Path $workerPath "..")
$runtimeDir = Join-Path (Split-Path $repoRoot -Parent) "runtime"
$localDb = Join-Path $repoRoot "server\data\rodzinna_lista.sqlite"
$dataSql = Join-Path $runtimeDir "d1-data.sql"
$wranglerConfig = Join-Path $workerPath "wrangler.jsonc"

function Run-Step {
  param(
    [string]$Title,
    [scriptblock]$Command
  )

  Write-Host ""
  Write-Host "==> $Title"
  & $Command
}

Run-Step "Instalowanie narzedzi Cloudflare" {
  Push-Location $workerPath
  try {
    npm install
  } finally {
    Pop-Location
  }
}

Run-Step "Sprawdzanie logowania Cloudflare" {
  Push-Location $workerPath
  try {
    $whoamiOutput = npx wrangler whoami 2>&1 | Out-String
    Write-Host $whoamiOutput
    if ($LASTEXITCODE -ne 0 -or $whoamiOutput -match "not authenticated|not logged in") {
      npx wrangler login
      npx wrangler whoami
    }
  } finally {
    Pop-Location
  }
}

$configText = Get-Content -LiteralPath $wranglerConfig -Raw
if ($configText -match "REPLACE_WITH_D1_DATABASE_ID") {
  Run-Step "Tworzenie bazy D1" {
    Push-Location $workerPath
    try {
      $createOutput = npx wrangler d1 create $DatabaseName 2>&1 | Out-String
      Write-Host $createOutput
      $databaseId = [regex]::Match(
        $createOutput,
        "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
      ).Value
      if (-not $databaseId) {
        throw "Nie udalo sie odczytac database_id z wyniku wrangler d1 create."
      }
      (Get-Content -LiteralPath $wranglerConfig -Raw).Replace(
        "REPLACE_WITH_D1_DATABASE_ID",
        $databaseId
      ) | Set-Content -LiteralPath $wranglerConfig -Encoding UTF8
      Write-Host "D1 database_id: $databaseId"
    } finally {
      Pop-Location
    }
  }
}

Run-Step "Wgrywanie migracji D1" {
  Push-Location $workerPath
  try {
    npx wrangler d1 migrations apply $DatabaseName --remote
  } finally {
    Pop-Location
  }
}

if (Test-Path -LiteralPath $localDb) {
  Run-Step "Eksport obecnej lokalnej bazy do SQL" {
    Push-Location $repoRoot
    try {
      node cloudflare-worker\scripts\export-d1-data.cjs $localDb $dataSql
    } finally {
      Pop-Location
    }
  }

  Run-Step "Wgrywanie obecnych danych do D1" {
    Push-Location $workerPath
    try {
      npx wrangler d1 execute $DatabaseName --remote --file $dataSql
    } finally {
      Pop-Location
    }
  }
}

$deployOutput = ""
Run-Step "Deploy Cloudflare Worker" {
  Push-Location $workerPath
  try {
    $script:deployOutput = cmd /c "npx wrangler deploy --minify 2>&1"
    if ($LASTEXITCODE -ne 0) {
      throw ($script:deployOutput | Out-String)
    }
    Write-Host $script:deployOutput
  } finally {
    Pop-Location
  }
}

$workerUrl = [regex]::Match(
  $deployOutput,
  "https://[a-zA-Z0-9.-]+\.workers\.dev"
).Value
if (-not $workerUrl) {
  throw "Nie udalo sie odczytac URL Workera z wyniku deploy."
}

Run-Step "Zapis nowego adresu serwera" {
  @(
    "SERVER_TYPE=cloudflare-workers-d1",
    "SERVER_URL=$workerUrl",
    "D1_DATABASE=$DatabaseName"
  ) | Set-Content -Path (Join-Path $runtimeDir "cloudflare-hosting.env") -Encoding UTF8
}

Run-Step "Budowanie APK z nowym hostingiem" {
  Push-Location $repoRoot
  try {
    flutter build apk --release --dart-define=SERVER_URL=$workerUrl
    Copy-Item -LiteralPath "build\app\outputs\flutter-apk\app-release.apk" -Destination $OutputApk -Force
  } finally {
    Pop-Location
  }
}

Write-Host ""
Write-Host "Gotowe. Nowy serwer: $workerUrl"
Write-Host "APK: $OutputApk"

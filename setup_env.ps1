# --- setup_env.ps1 (PowerShell 5.1 kompatibel) -------------------------------
param(
  [string]$FlutterSdk = "X:\dev\flutter\sdk",
  [string]$AndroidSdk = "X:\dev\android\sdk",
  [string]$JavaHome   = "C:\Program Files\Eclipse Adoptium\jdk-17.0.16.8-hotspot"
)

function Add-ToUserPath([string]$dir) {
  if (-not (Test-Path -LiteralPath $dir)) { return }
  $current = [Environment]::GetEnvironmentVariable("Path","User")
  if (-not $current) { $current = "" }
  $parts = ($current -split ';') | Where-Object { $_ -ne "" }
  if ($parts -notcontains $dir) {
    $new = ($parts + $dir) -join ';'
    [Environment]::SetEnvironmentVariable("Path",$new,"User")
    Write-Host "PATH + $dir"
  } else {
    Write-Host "PATH ok: $dir"
  }
}

function Show-Cmd([string]$name) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if ($cmd) { Write-Host ("  {0}: {1}" -f $name, $cmd.Source) }
  else      { Write-Host ("  {0}: NOT FOUND" -f $name) }
}

function Get-ProjectRoot([string]$startPath) {
  if (-not (Test-Path -LiteralPath $startPath)) { $startPath = $PSScriptRoot }
  $dir = Get-Item -LiteralPath $startPath
  while ($dir -and -not (Test-Path -LiteralPath (Join-Path $dir.FullName 'pubspec.yaml'))) {
    if (-not $dir.Parent) { break }
    $dir = $dir.Parent
  }
  if ($dir -and (Test-Path -LiteralPath (Join-Path $dir.FullName 'android'))) {
    return $dir.FullName
  }
  return $PSScriptRoot
}

# Pfade kurz prüfen
foreach ($p in @($FlutterSdk,$AndroidSdk,$JavaHome)) {
  if (-not (Test-Path -LiteralPath $p)) { Write-Host "WARN: Pfad existiert nicht -> $p" -ForegroundColor Yellow }
}

# Projektroot ermitteln & local.properties schreiben
$projectRoot = Get-ProjectRoot -startPath $PSScriptRoot
$androidDir  = Join-Path $projectRoot 'android'
if (-not (Test-Path -LiteralPath $androidDir)) {
  New-Item -ItemType Directory -Force -Path $androidDir | Out-Null
}

$localPropsPath = Join-Path $androidDir 'local.properties'
"sdk.dir=$AndroidSdk`nflutter.sdk=$FlutterSdk" | Set-Content -Encoding ASCII $localPropsPath
Write-Host "geschrieben: $localPropsPath"

# ENV Variablen (nur aktuelle Session)
$env:FLUTTER_ROOT     = $FlutterSdk
$env:ANDROID_SDK_ROOT = $AndroidSdk
$env:JAVA_HOME        = $JavaHome

# PATH dauerhaft (User) ergänzen
Add-ToUserPath "$FlutterSdk\bin"
Add-ToUserPath "$AndroidSdk\platform-tools"
Add-ToUserPath "$AndroidSdk\cmdline-tools\latest\bin"
Add-ToUserPath "$AndroidSdk\tools\bin"
Add-ToUserPath "$JavaHome\bin"

# PATH für diese Session ergänzen
$addNow = @("$FlutterSdk\bin",
            "$AndroidSdk\platform-tools",
            "$AndroidSdk\cmdline-tools\latest\bin",
            "$AndroidSdk\tools\bin",
            "$JavaHome\bin")
$env:Path = ($env:Path.Split(';') + $addNow | Select-Object -Unique) -join ';'

# Optional: Gradle in diesem Projekt auf Java 17 pinnen
$gradleProps = Join-Path $androidDir 'gradle.properties'
if (Test-Path -LiteralPath $gradleProps) {
  $content = Get-Content -LiteralPath $gradleProps -Raw
  if ($content -notmatch 'org\.gradle\.java\.home=') {
    Add-Content -LiteralPath $gradleProps "`norg.gradle.java.home=$JavaHome"
    Write-Host "android/gradle.properties: org.gradle.java.home gesetzt."
  }
}

Write-Host ""
Write-Host "Fertig. Öffne ein *neues* Terminal, damit PATH-Änderungen aktiv werden." -ForegroundColor Green
Write-Host "Kurztest (diese Session):"
Show-Cmd 'flutter'
Show-Cmd 'adb'
Show-Cmd 'java'
# ---------------------------------------------------------------------------

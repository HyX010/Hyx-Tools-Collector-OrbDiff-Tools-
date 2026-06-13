Write-Host @"
 ██╗  ██╗██╗   ██╗██╗  ██╗          ████████╗ ██████╗  ██████╗ ██╗     
 ██║  ██║╚██╗ ██╔╝╚██╗██╔╝          ╚══██╔══╝██╔═══██╗██╔═══██╗██║     
 ███████║ ╚████╔╝  ╚███╔╝              ██║   ██║   ██║██║   ██║██║     
 ██╔══██║  ╚██╔╝   ██╔██╗              ██║   ██║   ██║██║   ██║██║     
 ██║  ██║   ██║   ██╔╝ ██╗             ██║   ╚██████╔╝╚██████╔╝███████╗
 ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝             ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝

                         ██████╗ ██████╗ ██╗     ██╗     ███████╗ ██████╗████████╗ ██████╗ ██████╗ 
                        ██╔════╝██╔═══██╗██║     ██║     ██╔════╝██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗
                        ██║     ██║   ██║██║     ██║     █████╗  ██║        ██║   ██║   ██║██████╔╝
                        ██║     ██║   ██║██║     ██║     ██╔══╝  ██║        ██║   ██║   ██║██╔══██╗
                        ╚██████╗╚██████╔╝███████╗███████╗███████╗╚██████╗   ██║   ╚██████╔╝██║  ██║
                         ╚═════╝ ╚═════╝ ╚══════╝╚══════╝╚══════╝ ╚═════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝
"@ -ForegroundColor Magenta

Write-Host "                          Made with love by Hyx <3" -ForegroundColor White
Write-Host ""

# Verificar administrador
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Este script requiere permisos de administrador." -ForegroundColor Yellow
    Write-Host "Reiniciando como administrador..." -ForegroundColor Yellow
    
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "PowerShell"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    $psi.Verb = "RunAs"
    
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        exit
    }
    catch {
        Write-Host "No se pudo obtener permisos de administrador." -ForegroundColor Red
        exit
    }
}

# Carpeta de descarga
$DownloadPath = "C:\HyxTools"
if (!(Test-Path $DownloadPath)) {
    New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
}

# Función para agregar exclusión de Windows Defender
function Add-DefenderExclusion {
    Write-Host "`nConfigurando exclusión de antivirus..." -ForegroundColor Magenta
    Write-Host "Agregando exclusión de Windows Defender para $DownloadPath" -NoNewline
    
    $success = $false
    
    try {
        if (Get-Command Get-MpPreference -ErrorAction SilentlyContinue) {
            $existingExclusions = (Get-MpPreference -ErrorAction Stop).ExclusionPath
            if ($existingExclusions -notcontains $DownloadPath) {
                Add-MpPreference -ExclusionPath $DownloadPath -ErrorAction Stop
            }
            Write-Host " Éxito" -ForegroundColor Green
            $success = $true
        }
    }
    catch {
        # Silencio
    }
    
    if (-not $success) {
        try {
            $regPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths"
            if (Test-Path $regPath) {
                $existingValue = Get-ItemProperty -Path $regPath -Name $DownloadPath -ErrorAction SilentlyContinue
                if (-not $existingValue) {
                    New-ItemProperty -Path $regPath -Name $DownloadPath -Value 0 -PropertyType DWORD -Force -ErrorAction Stop | Out-Null
                }
                Write-Host " Éxito" -ForegroundColor Green
                $success = $true
            }
        }
        catch {
            # Silencio
        }
    }
    
    if (-not $success) {
        Write-Host " Falló" -ForegroundColor Red
    }
    
    return $success
}

$exclusionAdded = Add-DefenderExclusion

if (-not $exclusionAdded) {
    Write-Host "`nNo se pudo agregar exclusión automática. Posiblemente uses un antivirus de terceros." -ForegroundColor Yellow
    Write-Host "`nContinuando con las descargas..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
}

# Función para descargar archivos
function Download-File {
    param([string]$Url, [string]$FileName, [string]$ToolName)
    
    try {
        $outputPath = Join-Path $DownloadPath $FileName
        Write-Host "  Descargando $ToolName" -NoNewline
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $outputPath -UserAgent "PowerShell" -UseBasicParsing | Out-Null
        
        if ($FileName -like "*.zip") {
            $extractPath = Join-Path $DownloadPath ($FileName -replace '\.zip$', '')
            Expand-Archive -Path $outputPath -DestinationPath $extractPath -Force | Out-Null
            Remove-Item $outputPath -Force | Out-Null
        }
        Write-Host " Completado" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host " Falló" -ForegroundColor Red
        return $false
    }
    finally {
        $ProgressPreference = 'Continue'
    }
}

# Función para descargar desde releases de GitHub
function Download-GitHubRelease {
    param([string]$Repo, [string]$Version, [string]$AssetName, [string]$ToolName)
    
    $url = "https://github.com/$Repo/releases/download/$Version/$AssetName"
    return Download-File -Url $url -FileName $AssetName -ToolName $ToolName
}

# Lista de herramientas de Orbdiff (CORREGIDA)
$orbdiffTools = @(
    @{ Repo="Orbdiff/PrefetchView"; Version="v1.6.7"; Asset="PrefetchView++.exe"; Name="pv++" }
    @{ Repo="Orbdiff/BAMReveal"; Version="v1.3.1"; Asset="BAMReveal.exe"; Name="BAMReveal" }
    @{ Repo="Orbdiff/StringsParser"; Version="v1.0"; Asset="StringsParser.exe"; Name="StringsParser" }
    @{ Repo="Orbdiff/Fileless"; Version="v1.3"; Asset="Fileless.exe"; Name="Fileless" }
    @{ Repo="Orbdiff/DPS-Analyzer"; Version="v1.1"; Asset="DPS-Analyzer.exe"; Name="dpsanalyzer" }
    @{ Repo="Orbdiff/UserAssistView"; Version="v1.0"; Asset="UserAssistView.exe"; Name="UserAssistView" }
    @{ Repo="Orbdiff/JournalParser"; Version="v1.2"; Asset="JournalParser.exe"; Name="JournalParser" }
    @{ Repo="Orbdiff/MFT-HardLink"; Version="v1.2"; Asset="MFT-HardLink.exe"; Name="HardLink" }
    @{ Repo="Orbdiff/AmcacheParser"; Version="v1.0"; Asset="AmcacheParser.exe"; Name="Orbdiff AmcacheParser" }
    @{ Repo="Orbdiff/CheckDeletedUSN"; Version="v0.2.1"; Asset="CheckDeletedUSN.exe"; Name="CheckDeletedUSN" }
    @{ Repo="Orbdiff/USBDetector"; Version="v1.1"; Asset="USBDetector.exe"; Name="USBDetector" }
    @{ Repo="Orbdiff/JARParser"; Version="v1.2"; Asset="JARParser.exe"; Name="JARParser" }
    @{ Repo="Orbdiff/PFTrace"; Version="v1.0.1"; Asset="PFTrace.exe"; Name="PFTrace" }
)

# Menú principal
Write-Host "`n=======================================" -ForegroundColor Magenta
Write-Host "   HYX TOOLS COLLECTOR - ORBDIFF" -ForegroundColor Magenta
Write-Host "=======================================" -ForegroundColor Magenta

$response = Read-Host "`n¿Descargar todas las herramientas de Orbdiff? (Y/N)"

if ($response -match '^[Yy]') {
    Write-Host "`nDescargando herramientas de Orbdiff..." -ForegroundColor Magenta
    
    $successCount = 0
    foreach ($tool in $orbdiffTools) {
        if (Download-GitHubRelease -Repo $tool.Repo -Version $tool.Version -AssetName $tool.Asset -ToolName $tool.Name) {
            $successCount++
        }
    }
    
    Write-Host "`nOrbdiff: $successCount/$($orbdiffTools.Count) herramientas descargadas exitosamente" -ForegroundColor Magenta
} else {
    Write-Host "`nDescarga cancelada." -ForegroundColor Yellow
}

Write-Host "`n=======================================" -ForegroundColor Magenta
Write-Host "  Herramientas guardadas en: $DownloadPath" -ForegroundColor White
Write-Host "=======================================" -ForegroundColor Magenta

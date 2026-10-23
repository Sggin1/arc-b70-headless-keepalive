# Sample Arc dedicated/shared GPU memory, available RAM and the Windows screen list
# on a timer while a llama-server holds a model on the Arc. Writes every line to -LogFile.
#
#   .\watch_arc.ps1 -Exe <llama-server.exe> -Model <model.gguf> -Device Vulkan1 -Port 8084 `
#                   -LogFile .\data\run.log [-Keepalive] [-Samples 36] [-Every 5]
#   .\watch_arc.ps1 -NoStart -Port 8084 -LogFile .\data\run.log   # watch a server that is already up
#
# GPU adapters are printed by the first 8 hex digits of their LUID. Which one is the Arc is
# NOT detected: it is the one whose dedicated usage rises when the model loads.
# Aborts and kills llama-server if available RAM drops below -MinAvailGB.
param(
  [string]$Exe, [string]$Model, [string]$Device = "Vulkan1", [int]$Port = 8084, [int]$Ctx = 4096,
  [int]$Samples = 36, [int]$Every = 5, [switch]$Keepalive, [switch]$NoStart,
  [string]$LogFile = ".\watch_arc.log", [double]$MinAvailGB = 5
)
Add-Type -AssemblyName System.Windows.Forms
function Out-Both($t) { $t; Add-Content -Path $LogFile -Value $t }

function Snap {
  $ded = @{}; $sh = @{}
  $id = '.*luid_0x00000000_(0x[0-9a-f]+)_phys.*'
  (Get-Counter '\GPU Adapter Memory(*)\Dedicated Usage').CounterSamples | % { $ded[($_.Path -replace $id,'$1')] = $_.CookedValue/1GB }
  (Get-Counter '\GPU Adapter Memory(*)\Shared Usage').CounterSamples    | % { $sh[($_.Path -replace $id,'$1')]  = $_.CookedValue/1GB }
  $avail = (Get-Counter '\Memory\Available MBytes').CounterSamples[0].CookedValue/1024
  $gpu = foreach ($k in $ded.Keys) { "{0}: ded {1:N2} sh {2:N2}" -f $k, $ded[$k], $sh[$k] }
  $scr = ([System.Windows.Forms.Screen]::AllScreens | % { "$($_.DeviceName.Replace('\',''))=$($_.Bounds.Width)x$($_.Bounds.Height)" }) -join ","
  return @{ avail = $avail; line = ("{0:HH:mm:ss} availRAM {1:N1} | {2} | screens {3}" -f (Get-Date), $avail, ($gpu -join " | "), $scr) }
}

$logDir = Split-Path -Parent $LogFile
if ($logDir) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
Out-Both ("# watch_arc start {0:yyyy-MM-dd HH:mm:ss}  keepalive={1}  nostart={2}" -f (Get-Date), $Keepalive.IsPresent, $NoStart.IsPresent)

if (-not $NoStart) {
  Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep 3
  $srvLog = Join-Path $env:TEMP "watch-arc-server.log"
  Start-Process $Exe -ArgumentList @("-m",$Model,"--port",$Port,"-ngl","99","--device",$Device,"-c",$Ctx) `
    -RedirectStandardError $srvLog -RedirectStandardOutput "$srvLog.out" -WindowStyle Hidden | Out-Null
  $ok = $false
  for ($i = 0; $i -lt 120; $i += 3) {
    Start-Sleep 3
    try { if ((Invoke-WebRequest "http://127.0.0.1:$Port/health" -UseBasicParsing -TimeoutSec 3).StatusCode -eq 200) { $ok = $true; break } } catch {}
  }
  if (-not $ok) { Out-Both "server failed to come up"; exit 1 }
  Out-Both "# server healthy after about ${i}s"
}

$ka = $null
if ($Keepalive) {
  $ka = Start-Process powershell -WindowStyle Hidden -PassThru -ArgumentList "-NoProfile","-File",(Join-Path $PSScriptRoot "keepalive.ps1"),"-Port",$Port,"-IntervalSec","5"
  Out-Both "# keepalive started"
}

for ($n = 0; $n -lt $Samples; $n++) {
  $s = Snap; Out-Both $s.line
  if ($s.avail -lt $MinAvailGB) { Out-Both "# ABORT: available RAM below $MinAvailGB GB"; Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force; break }
  Start-Sleep $Every
}
if ($ka) { Stop-Process -Id $ka.Id -Force -ErrorAction SilentlyContinue; Out-Both "# keepalive stopped" }
Out-Both "# done (server left running)"

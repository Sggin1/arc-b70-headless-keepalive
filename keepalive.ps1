# arcrun: keep a headless Arc card awake by sending llama-server a tiny request on a timer.
#
#   .\keepalive.ps1 -Port 8084 [-IntervalSec 5]
#
# Why: with no display attached (no dummy dongle), the Intel driver was seen to
# offload a headless Arc Pro B70 into system RAM. A small periodic request keeps
# the card active. STATUS: untested rewrite of an earlier script that was lost;
# the interval (3, 5 or 10 s) was recalled from memory, not measured.
# Verify with the dongle removed: dedicated memory should stay on the card and
# shared GPU memory should stay near zero while a model is loaded.
param(
  [Parameter(Mandatory=$true)][int]$Port,
  [int]$IntervalSec = 5
)

$url  = "http://127.0.0.1:$Port/completion"
$body = '{"prompt":" ","n_predict":1,"cache_prompt":true}'
Write-Host "[keepalive] nudging $url every ${IntervalSec}s (Ctrl+C to stop)"

while ($true) {
  try {
    Invoke-WebRequest $url -Method Post -Body $body -ContentType "application/json" `
      -UseBasicParsing -TimeoutSec 20 | Out-Null
  } catch {
    Write-Host "[keepalive] $(Get-Date -Format HH:mm:ss) request failed: $($_.Exception.Message)"
  }
  Start-Sleep -Seconds $IntervalSec
}

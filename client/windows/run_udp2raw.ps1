$exe = "C:\Tools\udp2raw.exe"
$args = @(
  "-c",
  "-l","127.0.0.1:50001",
  "-r","<ip>",
  "-k","<password>",
  "--cipher-mode","xor",
  "--auth-mode","simple",
  "--raw-mode","faketcp"
)

$logDir = "C:\Tools\logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$stdoutLog = Join-Path $logDir "udp2raw.out.log"
$stderrLog = Join-Path $logDir "udp2raw.err.log"

Start-Process -FilePath $exe -ArgumentList $args -WindowStyle Hidden -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog

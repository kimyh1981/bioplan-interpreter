# 바이오플랜 동시통역 — 노트북 설치(브라우저 다운로드 경고 없이)
# 쓰는 법: Win+R → 아래 한 줄 붙여넣기 → Enter
#   powershell -ep Bypass -c "irm https://raw.githubusercontent.com/kimyh1981/bioplan-interpreter/main/install.ps1 | iex"
# 하는 일: 깃허브 최신 릴리스의 설치 파일을 받아 SHA256SUMS.txt의 지문과 맞는지 확인한 뒤 실행한다(다르면 실행 안 함).
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'      # PowerShell 5.1은 진행 막대 때문에 내려받기가 매우 느리다
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$repo = 'kimyh1981/bioplan-interpreter'
$name = 'BioplanInterpreter_PC_Setup.exe'
$ua = @{ 'User-Agent' = 'bioplan-interpreter-install' }

function Get-Asset($asset, $out) {
  # 다운로드 링크가 막히면(2026-11-08 504 실측) 깃허브 API 경로로
  try { Invoke-WebRequest $asset.browser_download_url -OutFile $out -UseBasicParsing -Headers $ua }
  catch { Invoke-WebRequest $asset.url -OutFile $out -UseBasicParsing -Headers ($ua + @{ 'Accept' = 'application/octet-stream' }) }
}

try {
  Write-Host ''
  Write-Host ' 바이오플랜 동시통역 설치 파일을 받습니다 (약 106MB, 1~3분)...' -ForegroundColor Cyan
  $rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers $ua
  $exe = $rel.assets | Where-Object { $_.name -eq $name }
  $sums = $rel.assets | Where-Object { $_.name -eq 'SHA256SUMS.txt' }
  if (-not $exe -or -not $sums) { throw '최신 버전에서 설치 파일을 찾지 못했습니다' }
  $dir = Join-Path $env:TEMP 'bioplan-interpreter-install'
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $dst = Join-Path $dir $name
  $sumFile = Join-Path $dir 'SHA256SUMS.txt'
  Get-Asset $sums $sumFile
  Get-Asset $exe $dst
  $want = (Get-Content $sumFile | Where-Object { $_ -match [regex]::Escape($name) } | Select-Object -First 1) -split '\s+' | Select-Object -First 1
  $got = (Get-FileHash $dst -Algorithm SHA256).Hash.ToLower()
  if (-not $want -or $got -ne $want.ToLower()) { Remove-Item $dst -Force; throw '받은 파일의 지문이 맞지 않아 실행하지 않았습니다 — 잠시 뒤 다시 해 주세요' }
  Write-Host (' 받기 완료 · ' + $rel.tag_name + ' · 지문 확인됨') -ForegroundColor Green
  if ($env:BIOPLAN_INSTALL_DRYRUN) { Write-Host " (시험 실행 — 설치는 하지 않음) $dst"; return }
  Write-Host ' 설치를 시작합니다. 검은 창이 뜨면 Enter를 누르고 기다려 주세요.' -ForegroundColor Cyan
  Start-Process -FilePath $dst -Wait
} catch {
  Write-Host ''
  Write-Host (' 설치하지 못했습니다: ' + $_.Exception.Message) -ForegroundColor Yellow
  Write-Host ' 인터넷을 확인하고 다시 해 보거나, AX 총괄(글로벌사업팀)에게 화면을 보내 주세요.'
  Read-Host ' Enter를 누르면 닫힙니다' | Out-Null
}

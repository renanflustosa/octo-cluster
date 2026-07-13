# Local HTML preview + one-click publish confirm for LinkedIn drafts.
param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [int]$Port = 0,

    [switch]$NoWait
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\..\scripts\_load-env.ps1')

$root = Get-OctoClusterRoot
$publishScript = Join-Path $PSScriptRoot 'invoke-linkedin-publish.ps1'

$manifestPathResolved = if ([System.IO.Path]::IsPathRooted($ManifestPath)) {
    $ManifestPath
} else {
    Join-Path $root ($ManifestPath -replace '/', '\')
}

if (-not (Test-Path $manifestPathResolved)) {
    Write-Error "Manifest not found: $manifestPathResolved"
    exit 1
}

$manifest = Get-Content -Path $manifestPathResolved -Raw -Encoding UTF8 | ConvertFrom-Json
$draftDir = Split-Path $manifestPathResolved -Parent
$ts = if ($manifest.timestamp) { [string]$manifest.timestamp } else { (Get-Date).ToString('yyyyMMdd-HHmm') }
$ticket = if ($manifest.ticket) { [string]$manifest.ticket } else { 'draft' }
$previewPath = Join-Path $draftDir "$ticket-$ts-preview.html"

function Get-ImageDataUri {
    param([string]$ImagePath)
    if (-not $ImagePath) { return '' }
    $resolved = if ([System.IO.Path]::IsPathRooted($ImagePath)) {
        $ImagePath
    } else {
        Join-Path $root ($ImagePath -replace '/', '\')
    }
    if (-not (Test-Path $resolved)) { return '' }
    $bytes = [System.IO.File]::ReadAllBytes($resolved)
    return 'data:image/png;base64,' + [Convert]::ToBase64String($bytes)
}

function Escape-Html {
    param([string]$Text)
    if (-not $Text) { return '' }
    return [System.Net.WebUtility]::HtmlEncode($Text)
}

$imgEn = Get-ImageDataUri -ImagePath ([string]$manifest.images.en)
$imgPt = Get-ImageDataUri -ImagePath ([string]$manifest.images.pt)
$postEnHtml = Escape-Html ([string]$manifest.posts.en)
$postPtHtml = Escape-Html ([string]$manifest.posts.pt)
$imgEnTag = if ($imgEn) { "<img src=`"$imgEn`" alt=`"EN image`"/>" } else { '' }
$imgPtTag = if ($imgPt) { "<img src=`"$imgPt`" alt=`"PT image`"/>" } else { '' }

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>LinkedIn preview — $ticket</title>
  <style>
    * { box-sizing: border-box; }
    body { font-family: system-ui, sans-serif; margin: 0; background: #0f1419; color: #e7e9ea; }
    header { padding: 1rem 1.5rem; border-bottom: 1px solid #38444d; }
    h1 { margin: 0; font-size: 1.25rem; }
    .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; padding: 1rem; }
    @media (max-width: 900px) { .grid { grid-template-columns: 1fr; } }
    .card { background: #16202a; border-radius: 12px; padding: 1rem; border: 1px solid #38444d; }
    .card h2 { margin-top: 0; font-size: 1rem; color: #1d9bf0; }
    img { max-width: 100%; border-radius: 8px; margin-bottom: 0.75rem; }
    pre { white-space: pre-wrap; word-break: break-word; font-size: 0.9rem; line-height: 1.45; background: #0f1419; padding: 0.75rem; border-radius: 8px; }
    .actions { display: flex; gap: 0.5rem; flex-wrap: wrap; margin-top: 0.75rem; }
    button { cursor: pointer; border: none; border-radius: 999px; padding: 0.6rem 1.2rem; font-weight: 600; font-size: 0.9rem; }
    .publish { background: #0a66c2; color: #fff; }
    .copy { background: #38444d; color: #fff; }
    #status { padding: 0.75rem 1.5rem; min-height: 2.5rem; }
    .ok { color: #00ba7c; }
    .err { color: #f4212e; }
  </style>
</head>
<body>
  <header>
    <h1>LinkedIn preview — $ticket</h1>
    <p style="margin:0.25rem 0 0;color:#8899a6">Review posts and images. One click publishes via your private API provider.</p>
  </header>
  <div class="grid">
    <div class="card">
      <h2>EN-US</h2>
      $imgEnTag
      <pre id="post-en">$postEnHtml</pre>
      <div class="actions">
        <button class="publish" onclick="publish('en')">Publish EN</button>
        <button class="copy" onclick="copyText('post-en')">Copy EN</button>
      </div>
    </div>
    <div class="card">
      <h2>PT-BR</h2>
      $imgPtTag
      <pre id="post-pt">$postPtHtml</pre>
      <div class="actions">
        <button class="publish" onclick="publish('pt')">Publish PT</button>
        <button class="copy" onclick="copyText('post-pt')">Copy PT</button>
      </div>
    </div>
  </div>
  <div id="status"></div>
  <script>
    async function publish(locale) {
      const el = document.getElementById('status');
      el.textContent = 'Publishing ' + locale.toUpperCase() + '...';
      el.className = '';
      try {
        const res = await fetch('/publish?locale=' + locale, { method: 'POST' });
        const data = await res.json();
        if (data.ok) {
          el.textContent = 'Published ' + locale.toUpperCase() + (data.detail ? ': ' + data.detail : '');
          el.className = 'ok';
        } else {
          el.textContent = 'Failed: ' + (data.error || 'unknown');
          el.className = 'err';
        }
      } catch (e) {
        el.textContent = 'Failed: ' + e.message;
        el.className = 'err';
      }
    }
    function copyText(id) {
      const text = document.getElementById(id).textContent;
      navigator.clipboard.writeText(text).then(() => {
        const el = document.getElementById('status');
        el.textContent = 'Copied to clipboard.';
        el.className = 'ok';
      });
    }
  </script>
</body>
</html>
"@

Set-Content -Path $previewPath -Value $html -Encoding UTF8
Write-Host "PREVIEW_HTML=$previewPath" -ForegroundColor Green

if ($Port -le 0) { $Port = 8765 + (Get-Random -Maximum 500) }
$prefix = "http://127.0.0.1:$Port/"
$listener = [System.Net.HttpListener]::new()

try {
    $listener.Prefixes.Add($prefix)
    $listener.Start()
} catch {
    Write-Host "WARN: preview server unavailable ($($_.Exception.Message)) — open static HTML" -ForegroundColor Yellow
    if ($IsLinux -or $IsMacOS) { & xdg-open $previewPath 2>$null } else { Start-Process $previewPath }
    exit 0
}

Write-Host "[linkedin-preview] server $prefix (Ctrl+C to stop)" -ForegroundColor Cyan
if ($IsLinux -or $IsMacOS) { & xdg-open $prefix 2>$null } else { Start-Process $prefix }

if ($NoWait) {
    $serverScript = Join-Path $draftDir "$ticket-$ts-preview-server.ps1"
    @"
`$listener = [System.Net.HttpListener]::new()
`$listener.Prefixes.Add('$prefix')
`$listener.Start()
`$html = Get-Content -Raw -Encoding UTF8 '$previewPath'
`$publishScript = '$publishScript'
`$manifestFile = '$manifestPathResolved'
while (`$listener.IsListening) {
  `$ctx = `$listener.GetContext()
  `$req = `$ctx.Request; `$res = `$ctx.Response
  if (`$req.HttpMethod -eq 'POST' -and `$req.Url.LocalPath -eq '/publish') {
    `$locale = `$req.QueryString['locale']
    `$p = Start-Process powershell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',`$publishScript,'-ManifestPath',`$manifestFile,'-Locale',`$locale,'-Confirm') -Wait -PassThru -NoNewWindow
    `$body = if (`$p.ExitCode -eq 0) { '{"ok":true}' } else { '{"ok":false,"error":"publish failed"}' }
    `$buf = [Text.Encoding]::UTF8.GetBytes(`$body)
    `$res.ContentType = 'application/json'; `$res.OutputStream.Write(`$buf,0,`$buf.Length)
  } else {
    `$buf = [Text.Encoding]::UTF8.GetBytes(`$html)
    `$res.ContentType = 'text/html; charset=utf-8'; `$res.OutputStream.Write(`$buf,0,`$buf.Length)
  }
  `$res.Close()
}
"@ | Set-Content -Path $serverScript -Encoding UTF8
    Start-Process powershell -ArgumentList @('-NoProfile', '-WindowStyle', 'Hidden', '-File', $serverScript)
    Write-Host "[linkedin-preview] background server started" -ForegroundColor Green
    exit 0
}

while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response

    if ($req.HttpMethod -eq 'POST' -and $req.Url.LocalPath -eq '/publish') {
        $locale = [string]$req.QueryString['locale']
        if ($locale -notin @('en', 'pt')) {
            $body = '{"ok":false,"error":"invalid locale"}'
            $res.StatusCode = 400
        } else {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $publishScript `
                -ManifestPath $manifestPathResolved -Locale $locale -Confirm 2>&1 | Out-String | Out-Null
            $code = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
            if ($code -eq 0) {
                $body = '{"ok":true,"detail":"published"}'
            } else {
                $body = "{`"ok`":false,`"error`":`"exit $code`"}"
            }
        }
        $buf = [System.Text.Encoding]::UTF8.GetBytes($body)
        $res.ContentType = 'application/json'
        $res.OutputStream.Write($buf, 0, $buf.Length)
    } else {
        $buf = [System.Text.Encoding]::UTF8.GetBytes($html)
        $res.StatusCode = 200
        $res.ContentType = 'text/html; charset=utf-8'
        $res.OutputStream.Write($buf, 0, $buf.Length)
    }
    $res.Close()
}

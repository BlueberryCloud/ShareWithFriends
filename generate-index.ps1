# generate-index.ps1 — Web-safe index with relative links (HTML/JSON)
param(
  [string]$Root = (Get-Location).Path,
  [string]$Output = "index.html"
)

$ErrorActionPreference = "Stop"
$indexPath = Join-Path $Root $Output

# 1) Collect files (recursive), skip index.html itself
$files = Get-ChildItem -Path $Root -Recurse -File |
  Where-Object {
    $_.Extension -match '^\.(html|htm|json)$' -and
    $_.Name -notmatch '^index\.html?$'
  }

if (-not $files) {
  "" | Out-File -Encoding utf8 -FilePath $indexPath
  Write-Host "No files found under $Root"
  exit
}

# 2) Helpers
function Get-RelativePath([string]$full, [string]$root) {
  $rel = $full.Substring($root.Length).TrimStart('\','/')
  $rel -replace '\\','/'
}
function Encode-WebPath([string]$rel) {
  $segments = $rel -split '/'
  $encoded  = foreach ($s in $segments) { [System.Uri]::EscapeDataString([string]$s) }
  return ($encoded -join '/')
}

$HtmlEncode = { param($s) [System.Net.WebUtility]::HtmlEncode([string]$s) }

# 3) Build metadata
$items = $files | ForEach-Object {
  $rel = Get-RelativePath $_.FullName $Root
  [pscustomobject]@{
    Name      = $_.Name
    DirRel    = (Split-Path $rel -Parent)
    RelPath   = $rel
    WebPath   = Encode-WebPath $rel
    Ext       = $_.Extension.ToLowerInvariant()
    SizeKB    = [math]::Round($_.Length / 1024, 1)
    Modified  = $_.LastWriteTime
  }
}
$items | ForEach-Object { if (-not $_.DirRel) { $_.DirRel = "." } }
$groups = $items | Group-Object DirRel | Sort-Object Name

# 4) CSS
$style = @'
:root { --bg:#0f1020; --card:#17182b; --ink:#e9e9ff; --muted:#a5a7d4; --rule:#2a2b45; }
*{box-sizing:border-box} body{margin:0;font:15px/1.5 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:var(--bg);color:var(--ink);}
main{max-width:1100px;margin:40px auto;padding:24px;background:var(--card);border-radius:16px;box-shadow:0 8px 40px rgba(0,0,0,.35);}
h1{margin:0 0 12px;font-weight:700}
.folder{margin:18px 0 8px;font-weight:600}
ul{list-style:none;padding:0;margin:0}
li{padding:10px 12px;border-bottom:1px solid var(--rule);display:flex;gap:12px;align-items:center;flex-wrap:wrap}
li a{color:var(--ink);text-decoration:none} li a:hover{text-decoration:underline}
.badge{font-size:12px;padding:2px 6px;border:1px solid var(--rule);border-radius:999px;color:var(--muted)}
.meta{margin-left:auto;color:var(--muted);font-size:12px;display:flex;gap:12px}
.folderpath{color:var(--muted);font-size:13px;margin:2px 0 8px}
hr{border:0;border-top:1px solid var(--rule);margin:16px 0}
'@

# 5) HTML
$html = New-Object System.Text.StringBuilder
[void]$html.AppendLine('<!doctype html>')
[void]$html.AppendLine('<html lang="en">')
[void]$html.AppendLine('<meta charset="utf-8" />')
[void]$html.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1" />')
[void]$html.AppendLine('<title>ShareWithFriends - Index</title>')
[void]$html.AppendLine('<style>')
[void]$html.AppendLine($style)
[void]$html.AppendLine('</style>')
[void]$html.AppendLine('<main>')
[void]$html.AppendLine('<h1>ShareWithFriends - Index</h1>')

$rootEsc = & $HtmlEncode $Root
[void]$html.AppendLine("<div class=""folderpath"">Root: <code>$rootEsc</code></div>")
[void]$html.AppendLine('<hr />')

foreach ($g in $groups) {
  $folderLabel = if ($g.Name -eq ".") { "/" } else { "/$($g.Name)" }
  $folderEsc = & $HtmlEncode $folderLabel
  [void]$html.AppendLine("<div class=""folder"">$folderEsc</div>")
  [void]$html.AppendLine('<ul>')
  $g.Group | Sort-Object Name | ForEach-Object {
    $label = & $HtmlEncode $_.Name
    $href  = $_.WebPath
    $badge = if ($_.Ext -eq ".json") { "JSON" } elseif ($_.Ext -eq ".html" -or $_.Ext -eq ".htm") { "HTML" } else { $_.Ext.TrimStart('.') }
    $meta  = ("{0} KB · {1}" -f $_.SizeKB, $_.Modified.ToString('yyyy-MM-dd HH:mm'))
    $metaEsc = & $HtmlEncode $meta
    $line = "<li><a href=""$href"">$label</a> <span class=""badge"">$badge</span> <span class=""meta"">$metaEsc</span></li>"
    [void]$html.AppendLine($line)
  }
  [void]$html.AppendLine('</ul>')
}

[void]$html.AppendLine('</main></html>')

# 6) Write
$html.ToString() | Out-File -Encoding utf8 -FilePath $indexPath
Write-Host "Wrote $indexPath"

param(
  [switch]$LocalFileMode,  # if set, JSON links won't include ?src=
  [string]$Root   = "C:\Users\parm19\source\repos-share\sharewithfriends",
  [string]$Viewer = "json-viewer.html"
)

$indexPath = Join-Path $Root "index.html"

function Get-RepoRelativePath {
  param([string]$FullPath, [string]$Root)
  $rel = $FullPath.Substring($Root.Length)
  $rel = $rel -replace '^[=\\/]+',''   # strip stray leading = or slashes
  $rel = $rel -replace '\\','/'        # URL-style slashes
  return $rel
}

function HtmlEncode { param($s) return [System.Web.HttpUtility]::HtmlEncode([string]$s) }

# Collect files
$files = Get-ChildItem -Path $Root -Recurse -File |
  Where-Object { $_.Extension -match '^\.(html|htm|json)$' -and $_.Name -notmatch '^index\.html?$' } |
  Sort-Object FullName

# Group by folder
$groups = $files | ForEach-Object {
  $relDir = Split-Path $_.FullName -Parent
  $relDir = Get-RepoRelativePath -FullPath $relDir -Root $Root
  if ([string]::IsNullOrWhiteSpace($relDir)) { $relDir = "/" }
  [PSCustomObject]@{ DirRel = $relDir; File = $_ }
} | Group-Object DirRel | Sort-Object Name

# Build HTML
$html = @"
<!doctype html>
<html lang="en">
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>ShareWithFriends - Index</title>
<style>
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
</style>
<main>
<h1>ShareWithFriends - Index</h1>
<div class="folderpath">Root: <code>$(HtmlEncode $Root)</code></div>
<hr />
"@

foreach ($g in $groups) {
  $dirLabel = $g.Name
  $html += "<div class=`"folder`">$(HtmlEncode $dirLabel)</div>`n<ul>`n"
  foreach ($f in $g.Group) {
    # Build a repo-relative, percent-encoded HREF (raw for now)
    $relRaw = Get-RepoRelativePath -FullPath $f.File.FullName -Root $Root
    $relEsc = [System.Uri]::EscapeUriString($relRaw)

    $name = HtmlEncode $f.File.Name
    $ext  = ($f.File.Extension.TrimStart('.')).ToUpperInvariant()
    $kb   = [math]::Round($f.File.Length / 1024.0, 1)
    $dt   = $f.File.LastWriteTime.ToString("yyyy-MM-dd HH:mm")

    # Emit raw href first; we'll rewrite .json links in a single safe pass below
    $html += "<li><a href=""$relEsc"">$name</a> <span class=""badge"">$ext</span> <span class=""meta"">$kb KB &#183; $dt</span></li>`n"
  }
  $html += "</ul>`n"
}

$html += @"
</main></html>
"@

# --- Safety-net rewrite: force JSON links to go through the viewer -------------
# The generated hrefs are already percent-encoded, so do NOT re-encode.
if ($LocalFileMode) {
  # Local file browsing: viewer without ?src= (use file picker inside viewer)
  $html = [regex]::Replace($html, 'href="([^"]+\.json)"', 'href="' + $Viewer + '"')
} else {
  # Web/HTTP: route to viewer with ?src=<existing href>
  $html = [regex]::Replace($html, 'href="([^"]+\.json)"', 'href="' + $Viewer + '?src=$1"')
}

# Write file
$html | Out-File -FilePath $indexPath -Encoding utf8
Write-Host "index.html written to $indexPath (LocalFileMode=$LocalFileMode)"

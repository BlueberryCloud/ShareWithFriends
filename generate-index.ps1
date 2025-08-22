param(
  [switch]$LocalFileMode,  # when set, JSON links won't include ?src=
  [string]$Root   = "C:\Users\parm19\source\repos-share\sharewithfriends",
  [string]$Viewer = "json-viewer.html"  # sit this next to index.html on Cloudflare Pages
)

$indexPath = Join-Path $Root "index.html"

function Get-RepoRelativePath {
  param([string]$FullPath, [string]$Root)

  if ([string]::IsNullOrWhiteSpace($Root)) { throw "Root cannot be null or empty." }
  if ([string]::IsNullOrWhiteSpace($FullPath)) { return '' }

  try { $rootResolved = (Resolve-Path -LiteralPath $Root -ErrorAction Stop).Path }
  catch { $rootResolved = [IO.Path]::GetFullPath($Root) }
  $rootResolved = $rootResolved.TrimEnd('\','/')

  try { $fullResolved = (Resolve-Path -LiteralPath $FullPath -ErrorAction Stop).Path }
  catch { $fullResolved = [IO.Path]::GetFullPath($FullPath) }

  if ([string]::IsNullOrWhiteSpace($fullResolved)) { return '' }

  if ($fullResolved.StartsWith($rootResolved, [System.StringComparison]::OrdinalIgnoreCase)) {
    $rel = $fullResolved.Substring($rootResolved.Length).TrimStart('\','/')
  } else {
    $uRoot = [Uri](([IO.Path]::GetFullPath(($rootResolved.TrimEnd('\') + '\'))))
    $uFull = [Uri](([IO.Path]::GetFullPath($fullResolved)))
    $rel = $uRoot.MakeRelativeUri($uFull).ToString()
  }
  return ($rel -replace '\\','/')
}

# Skip noisy folders
$skipDirs = @('.git','bin','obj','node_modules')

# 1) Collect files
$extensions = @('html','htm','md','txt','pdf','json')
$files = Get-ChildItem -Path $Root -Recurse -File |
  Where-Object {
    $ext = $_.Extension.TrimStart('.')
    $extensions -contains $ext -and
    $_.Name -notmatch '^index\.html?$' -and
    ($skipDirs -notcontains $_.Directory.Name)
  } |
  Sort-Object FullName

# 2) Group by relative folder
$groups = $files | ForEach-Object {
  $dirFull = Split-Path $_.FullName -Parent
  $dirRel  = Get-RepoRelativePath -FullPath $dirFull -Root $Root
  if ([string]::IsNullOrWhiteSpace($dirRel)) { return } # skip bad
  [PSCustomObject]@{ DirRel = $dirRel; File = $_ }
} | Group-Object DirRel | Sort-Object Name

# 3) CSS
$css = @"
:root { --bg:#0f1020; --card:#17182b; --ink:#e9e9ff; --muted:#a5a7d4; --rule:#2a2b45; --accent:#7aa2ff; }
*{box-sizing:border-box}
body{margin:0;font:15px/1.5 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:var(--bg);color:var(--ink)}
main{max-width:1100px;margin:40px auto;padding:24px;background:var(--card);border-radius:16px;box-shadow:0 8px 40px rgba(0,0,0,.35)}
h1{margin:0 0 8px}
.summary-row{display:flex;justify-content:space-between;align-items:center;gap:12px}
summary{cursor:pointer;list-style:none;outline:none}
summary::-webkit-details-marker{display:none}
.folder{padding:12px 14px;border:1px solid var(--rule);border-radius:12px;margin:10px 0;background:#14152a}
.folder summary{font-weight:600}
.folder small{color:var(--muted)}
.folder ul{margin:10px 0 0 0;padding-left:18px}
.folder li{margin:4px 0}
.folder a{color:var(--ink);text-decoration:none;border-bottom:1px dotted var(--rule)}
.folder a:hover{border-bottom-color:var(--accent)}
.hr{height:1px;background:var(--rule);margin:18px 0}
header .meta{color:var(--muted);font-size:13px}
.search{width:100%;padding:10px 12px;border-radius:10px;border:1px solid var(--rule);background:#131428;color:var(--ink)}
.note{color:var(--muted);font-size:13px;margin-top:6px}
.badge{display:inline-block;padding:2px 8px;border:1px solid var(--rule);border-radius:999px;font-size:12px;margin-left:6px}
"@

# 4) Build HTML
$modeText = if ($LocalFileMode) { "LocalFileMode" } else { "Cloud (viewer ?src)" }
$html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>ShareWithFriends &mdash; Index</title>
<style>
$css
</style>
</head>
<body>
<main>
  <header>
    <h1>&#128193; ShareWithFriends &mdash; Index <span class="badge">$modeText</span></h1>
    <div class="meta">Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')  &bull;  Root: $((Resolve-Path $Root).Path)</div>
    <div class="hr"></div>
    <input class="search" id="filter" placeholder="Type to filter folders & files..." />
    <div class="note">Tip: each section below is collapsible. Click the folder name to expand. (All are closed by default.)</div>
  </header>
  <section id="folders">
"@

# 5) Folders
foreach ($g in $groups) {
  $folder = if ($g.Name -eq '/') { '— root —' } else { $g.Name }
  $count = $g.Group.Count

  $html += @'
  <details class="folder"><summary><div class="summary-row"><span>&#128193; {0}</span><small>{1} file(s)</small></div></summary>
    <ul>
'@ -f $folder, $count

  foreach ($entry in $g.Group) {
    $file = $entry.File
    if (-not $file) { continue }

    $relFile = Get-RepoRelativePath -FullPath $file.FullName -Root $Root
    if ([string]::IsNullOrWhiteSpace($relFile)) { continue }

    $name = $file.Name

    # Robust JSON detection (extension + name pattern)
    $isJson = $false
    $ext = [IO.Path]::GetExtension($file.Name)
    if ($ext) { $isJson = $isJson -or ($ext.Trim().ToLower() -eq '.json') }
    if (-not $isJson) { $isJson = $file.Name -like '*.json' }

    if ($isJson) {
      # Always link to viewer with ?src==<encoded rel path> for JSON files
      $href = "$($Viewer)?src=$([System.Uri]::EscapeDataString(($relFile -replace '\\','/')))"
    } else {
      # Non-JSON direct link
      $href = [System.Uri]::EscapeUriString($relFile)
    }

    $html += @'
      <li><a href="{0}">{1}</a></li>
'@ -f $href, $name
  }

  $html += @'
    </ul>
  </details>
'@
}

# 6) Footer + JS filter
$html += @"
  </section>
</main>
<script>
(function(){
  var input = document.getElementById('filter');
  var sections = Array.prototype.slice.call(document.querySelectorAll('details.folder'));
  function norm(s){ return (s||'').toLowerCase(); }
  input.addEventListener('input', function(){
    var q = norm(input.value.trim());
    sections.forEach(function(d){
      if (!q) { d.style.display = ''; return; }
      var text = norm(d.textContent || '');
      d.style.display = text.indexOf(q) !== -1 ? '' : 'none';
    });
  });
})();
</script>
</body>
</html>
"@

# 7) Write file (UTF-8)
$html | Out-File -FilePath $indexPath -Encoding utf8
Write-Host "index.html written to $indexPath (LocalFileMode=$LocalFileMode)"

# 8) Debug logging for JSON detection
Write-Host "=== DEBUG: JSON File Detection ==="
$jsonFiles = $files | Where-Object { 
    $ext = [IO.Path]::GetExtension($_.Name)
    $isJson = ($ext.Trim().ToLower() -eq '.json') -or ($_.Name -like '*.json')
    if ($isJson) {
        Write-Host "JSON file found: $($_.FullName)"
        Write-Host "  Extension: '$ext'"
        Write-Host "  Name pattern match: $($_.Name -like '*.json')"
    }
    $isJson
}
Write-Host "Total JSON files found: $($jsonFiles.Count)"

# 9) Debug URL generation for JSON files
Write-Host "=== DEBUG: JSON URL Generation ==="
foreach ($jsonFile in $jsonFiles) {
    $relFile = Get-RepoRelativePath -FullPath $jsonFile.FullName -Root $Root
    $encodedPath = [System.Uri]::EscapeDataString($relFile)
    $viewerUrl = "$Viewer?src==$encodedPath"
    Write-Host "File: $($jsonFile.Name)"
    Write-Host "  Relative path: $relFile"
    Write-Host "  Encoded path: $encodedPath"
    Write-Host "  Viewer URL: $viewerUrl"
    Write-Host "---"
}

# 10) Execute the script if called directly
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
    Write-Host "Script executed successfully!"
}

# 11) Allow script to be run directly with parameters
if ($MyInvocation.InvocationName -eq $MyInvocation.MyCommand.Name) {
    # Script is being run directly, not dot-sourced
    Write-Host "Running generate-index.ps1..."
    Write-Host "Parameters: LocalFileMode=$LocalFileMode, Root=$Root, Viewer=$Viewer"
}

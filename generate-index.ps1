$root = "C:\Users\parm19\source\repos-share\sharewithfriends"
$indexPath = Join-Path $root "index.html"

# Find all .html files except index.html itself
$files = Get-ChildItem -Path $root -Recurse -Include *.html |
         Where-Object { $_.Name -ne "index.html" }

$html = @"
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Index of Files</title>
</head>
<body>
  <h1>Available Files</h1>
  <ul>
"@

foreach ($f in $files) {
    $rel = $f.FullName.Substring($root.Length).TrimStart('\','/')
    $html += "    <li><a href=""$rel"">$rel</a></li>`n"
}

$html += @"
  </ul>
</body>
</html>
"@

Set-Content -Path $indexPath -Value $html -Encoding UTF8

Write-Host "index.html generated at $indexPath"

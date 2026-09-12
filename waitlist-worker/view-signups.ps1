[CmdletBinding()]
param(
  [string]$ExportPath
)

$ErrorActionPreference = "Stop"
$workerDirectory = Split-Path -Parent $PSCommandPath
$wrangler = "C:\Program Files\nodejs\npx.cmd"
$query = "SELECT email, created_at FROM waitlist_signups ORDER BY created_at DESC"

if (-not (Test-Path $wrangler)) {
  throw "Wrangler was not found. Install Node.js, then run: npx wrangler login"
}

Push-Location $workerDirectory
try {
  if ($ExportPath) {
    $json = & $wrangler wrangler d1 execute sleepus-waitlist --remote --command $query --json
    if ($LASTEXITCODE -ne 0) {
      throw "Could not read the waitlist database. Run 'npx wrangler login' and try again."
    }

    $rows = ($json | ConvertFrom-Json)[0].results
    $rows | Export-Csv -Path $ExportPath -NoTypeInformation
    Write-Host "Exported $($rows.Count) signup(s) to $ExportPath"
    return
  }

  & $wrangler wrangler d1 execute sleepus-waitlist --remote --command $query
  if ($LASTEXITCODE -ne 0) {
    throw "Could not read the waitlist database. Run 'npx wrangler login' and try again."
  }
} finally {
  Pop-Location
}
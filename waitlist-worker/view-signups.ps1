[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$workerDirectory = Split-Path -Parent $PSCommandPath
$wrangler = "C:\Program Files\nodejs\npx.cmd"
$query = "SELECT email, created_at FROM waitlist_signups ORDER BY created_at DESC"

if (-not (Test-Path $wrangler)) {
  throw "Wrangler was not found. Install Node.js, then run: npx wrangler login"
}

Push-Location $workerDirectory
try {
  & $wrangler wrangler d1 execute sleepus-waitlist --remote --command $query
  if ($LASTEXITCODE -ne 0) {
    throw "Could not read the waitlist database. Run 'npx wrangler login' and try again."
  }
} finally {
  Pop-Location
}
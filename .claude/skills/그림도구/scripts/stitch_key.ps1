# Stitch API key -> user environment variable STITCH_API_KEY (from clipboard).
# Usage: copy the key in Stitch settings, then run this file once.
# The key is never printed and never written to any file.
$key = (Get-Clipboard -Raw)
if ($null -eq $key) { Write-Output "Clipboard is empty. Copy the Stitch key first."; exit 1 }
$key = $key.Trim()
if ($key.Length -lt 20 -or $key -match '\s') {
    Write-Output "Clipboard does not look like an API key. Copy the key again."
    exit 1
}
[Environment]::SetEnvironmentVariable('STITCH_API_KEY', $key, 'User')
$masked = $key.Substring(0, 4) + '...' + $key.Substring($key.Length - 4)
Write-Output "OK: STITCH_API_KEY saved for this Windows user ($masked)."
Write-Output "Now fully quit and reopen the Claude app so it can see the key."

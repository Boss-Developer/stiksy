# Prompts for the Supabase anon key every run instead of storing it anywhere,
# then forwards to `flutter run` along with any extra args you pass through.
#
# Usage:
#   .\run.ps1                 -> flutter run --dart-define=SUPABASE_ANON_KEY=...
#   .\run.ps1 -d <deviceId>   -> extra args are forwarded as-is

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
)

$secureKey = Read-Host -Prompt "Supabase anon key" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
$anonKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

if ([string]::IsNullOrWhiteSpace($anonKey)) {
    Write-Error "No key entered. Aborting."
    exit 1
}

flutter run --dart-define=SUPABASE_ANON_KEY=$anonKey @FlutterArgs

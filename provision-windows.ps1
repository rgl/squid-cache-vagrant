Set-StrictMode -Version Latest

$ErrorActionPreference = 'Stop'

trap {
    Write-Output "`nERROR: $_`n$($_.ScriptStackTrace)"
    Exit 1
}

# wrap the choco command (to make sure this script aborts when it fails).
function Start-Choco([string[]]$Arguments, [int[]]$SuccessExitCodes=@(0)) {
    &C:\ProgramData\chocolatey\bin\choco.exe @Arguments `
        | Where-Object { $_ -NotMatch '^Progress: ' }
    if ($SuccessExitCodes -NotContains $LASTEXITCODE) {
        throw "$(@('choco')+$Arguments | ConvertTo-Json -Compress) failed with exit code $LASTEXITCODE"
    }
}
function choco {
    Start-Choco $Args
}

# disable the IE first-launch thingy. it prevents us from using Invoke-WebRequest without the -UseBasicParsing flag.
# NB if we don't do this and try to use the Invoke-WebRequest cmdlet we get the error;
#       The response content cannot be parsed because the Internet Explorer engine
#       is not available, or Internet Explorer's first-launch configuration is not
#       complete. Specify the UseBasicParsing parameter and try again. 
# see http://www.geoffchappell.com/notes/windows/ie/firstrun.htm
Set-ItemProperty -Path 'HKLM:Software\Microsoft\Internet Explorer\Main' -Name DisableFirstRunCustomize -Value 1

# install Google Chrome and some useful extensions.
# see https://developer.chrome.com/extensions/external_extensions
choco install -y googlechrome
@(
    # JSON Formatter (https://chrome.google.com/webstore/detail/json-formatter/bcjindcccaagfpapjjmafapmmgkkhgoa).
    'bcjindcccaagfpapjjmafapmmgkkhgoa'
    # uBlock Origin (https://chrome.google.com/webstore/detail/ublock-origin/cjpalhdlnbpafiamejdnhcphjbkeiagm).
    'cjpalhdlnbpafiamejdnhcphjbkeiagm'
) | ForEach-Object {
    New-Item -Force -Path "HKLM:Software\Wow6432Node\Google\Chrome\Extensions\$_" `
        | Set-ItemProperty -Name update_url -Value 'https://clients2.google.com/service/update2/crx'
}

# replace notepad with notepad2.
choco install -y notepad2

# test with PowerShell.
Invoke-WebRequest http://httpbin.org/ip | Out-Null
Invoke-WebRequest https://httpbin.org/ip | Out-Null

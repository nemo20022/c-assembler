$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('assembler-constants-' + [guid]::NewGuid().ToString('N'))
$exe = Join-Path $temp 'assembler.exe'
$nl = [Environment]::NewLine
New-Item -ItemType Directory -Path $temp | Out-Null
try {
  $vcvars = 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat'
  $compile = 'cd /d "' + $temp + '" && call "' + $vcvars + '" >NUL && cl /nologo /W4 /std:c11 "' + (Join-Path $root 'main.c') + '" "' + (Join-Path $root 'scanner.c') + '" "' + (Join-Path $root 'parser.c') + '" /Fe:"' + $exe + '"'
  & cmd.exe /c $compile
  if ($LASTEXITCODE -ne 0) { throw "Compilation failed with exit code $LASTEXITCODE." }
  function Write-Asm([string]$Name, [string]$Text) {
    $path = Join-Path $temp $Name
    [IO.File]::WriteAllBytes($path, [Text.Encoding]::ASCII.GetBytes($Text + [char]0))
    return $path
  }
  function Run-Asm([string[]]$Arguments) {
    $errorFile = Join-Path $temp 'stderr.txt'
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    Push-Location $temp
    try { $output = & $exe @Arguments 2> $errorFile; $code = $LASTEXITCODE }
    finally { Pop-Location; $ErrorActionPreference = $old }
    return @{ Code = $code; Output = (($output | ForEach-Object { "$_" }) -join $nl); Error = if (Test-Path $errorFile) { Get-Content $errorFile -Raw } else { '' } }
  }
  function Check([string]$Name, [string]$Expected, [string[]]$Arguments) {
    $result = Run-Asm $Arguments
    if ($result.Code -ne 0 -or $result.Output -ne $Expected) { throw "FAIL ${Name}: got [$($result.Output)] code $($result.Code), expected [$Expected]" }
    Write-Host "PASS: $Name"
  }
  function Reject([string]$Name, [string[]]$Arguments) {
    $result = Run-Asm $Arguments
    if ($result.Code -eq 0) { throw "FAIL $Name was accepted" }
    Write-Host "PASS: $Name rejected"
  }
  $default = Write-Asm 'example.asm' ("mov reg1, 3" + $nl)
  Check 'default filename' '00000011' @()
  $cases = @(
    @{ R = 'reg1'; E = '00001010'; Flag = $false },
    @{ R = 'reg2'; E = '00001010' + $nl + '10001010'; Flag = $true },
    @{ R = 'reg3'; E = '00001010' + $nl + '10001011'; Flag = $false },
    @{ R = 'reg4'; E = '00001010' + $nl + '10001100'; Flag = $false },
    @{ R = 'reg5'; E = '00001010' + $nl + '10001101'; Flag = $false },
    @{ R = 'reg6'; E = '00001010' + $nl + '10001110'; Flag = $false }
  )
  foreach ($case in $cases) {
    $file = Write-Asm ($case.R + '.asm') ("mov " + $case.R + ', 10' + $nl)
    if ($case.Flag) { $cliArguments = @('-f', $file) } else { $cliArguments = @($file) }
    Check ("constant into " + $case.R + " expands via reg1") $case.E $cliArguments
  }
  Reject 'constant above 63' @((Write-Asm 'large.asm' ("mov reg2, 64" + $nl)))
  Reject 'negative constant' @((Write-Asm 'negative.asm' ("mov reg2, -1" + $nl)))
  Reject 'invalid destination reg7' @((Write-Asm 'reg7.asm' ("mov reg7, 10" + $nl)))
  Check 'register MOV unchanged' '10010110' @((Write-Asm 'move.asm' ("mov reg6, reg2" + $nl)))
  Check 'comments still work' '00000011' @((Write-Asm 'comments.asm' ("; comment" + $nl + "mov reg1, 3 ; trailing" + $nl)))
  Check 'NOT still works' '01010101' @((Write-Asm 'not.asm' ("not reg2, reg1" + $nl)))
  Check 'RAM write still works' '11000001' @((Write-Asm 'ram-write.asm' ("mov [reg2], reg1" + $nl)))
  Check 'RAM read still works' '11000000' @((Write-Asm 'ram-read.asm' ("mov reg1, [reg2]" + $nl)))
  Write-Host 'All constant-loading tests passed.'
}
finally { Remove-Item -LiteralPath $temp -Recurse -Force }

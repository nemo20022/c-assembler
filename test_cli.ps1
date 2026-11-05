$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('assembler-cli-' + [guid]::NewGuid().ToString('N'))
$exe = Join-Path $temp 'assembler.exe'
New-Item -ItemType Directory -Path $temp | Out-Null

try {
  $vcvars = 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat'
  $compile = 'cd /d "' + $temp + '" && call "' + $vcvars + '" >NUL && cl /nologo /W4 /std:c11 "' +
    (Join-Path $root 'main.c') + '" "' + (Join-Path $root 'scanner.c') + '" "' +
    (Join-Path $root 'parser.c') + '" /Fe:"' + $exe + '"'
  & cmd.exe /c $compile
  if ($LASTEXITCODE -ne 0) { throw "Compilation failed with exit code $LASTEXITCODE." }

  function Write-AssemblyFile([string]$Path, [string]$Text) {
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($Text + [char]0)
    [System.IO.File]::WriteAllBytes($Path, $bytes)
  }

  function Invoke-Assembler([string[]]$Arguments) {
    $errorFile = Join-Path $temp 'stderr.txt'
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    Push-Location $temp
    try {
      $output = & $exe @Arguments 2> $errorFile
      $code = $LASTEXITCODE
    } finally {
      Pop-Location
      $ErrorActionPreference = $previousPreference
    }
    return @{
      Code = $code
      Output = (($output | ForEach-Object { "$_" }) -join [Environment]::NewLine)
      Error = if (Test-Path $errorFile) { Get-Content $errorFile -Raw } else { '' }
    }
  }

  function Assert-Success([string]$Name, [string[]]$Arguments, [string]$Expected) {
    $result = Invoke-Assembler $Arguments
    if ($result.Code -ne 0 -or $result.Output -ne $Expected) {
      throw "FAIL: $Name. Exit $($result.Code), output [$($result.Output)]."
    }
    Write-Host "PASS: $Name"
  }

  function Assert-Failure([string]$Name, [string[]]$Arguments, [string]$ExpectedMessage) {
    $result = Invoke-Assembler $Arguments
    if ($result.Code -eq 0) { throw "FAIL: $Name was accepted." }
    if ($ExpectedMessage -and $result.Error -notmatch [regex]::Escape($ExpectedMessage)) {
      throw "FAIL: $Name did not show the expected error message."
    }
    Write-Host "PASS: $Name (rejected)"
  }

  Write-AssemblyFile (Join-Path $temp 'example.asm') "mov reg1, 3`n"
  Write-AssemblyFile (Join-Path $temp 'positional.asm') "mov reg1, 5`n"
  Write-AssemblyFile (Join-Path $temp 'flag.asm') "mov reg1, 6`n"

  Assert-Success 'default example.asm filename' @() '00000011'
  Assert-Success 'positional filename' @((Join-Path $temp 'positional.asm')) '00000101'
  Assert-Success '-f filename' @('-f', (Join-Path $temp 'flag.asm')) '00000110'
  Assert-Failure 'missing filename after -f' @('-f') 'Missing filename'
  Assert-Failure 'unknown option' @('--bad') 'Unknown option'
  Assert-Failure 'multiple positional filenames' @((Join-Path $temp 'positional.asm'), (Join-Path $temp 'flag.asm')) 'Multiple input filenames'
  Assert-Failure 'multiple filenames with -f' @('-f', (Join-Path $temp 'flag.asm'), (Join-Path $temp 'positional.asm')) 'Multiple input filenames'

  Write-Host 'All command-line tests passed.'
}
finally {
  Remove-Item -LiteralPath $temp -Recurse -Force
}

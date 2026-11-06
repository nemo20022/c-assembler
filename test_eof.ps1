$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('assembler-eof-' + [guid]::NewGuid().ToString('N'))
$exe = Join-Path $temp 'assembler.exe'
$nl = [Environment]::NewLine
New-Item -ItemType Directory -Path $temp | Out-Null
try {
  $vcvars = 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat'
  $compile = 'cd /d "' + $temp + '" && call "' + $vcvars + '" >NUL && cl /nologo /W4 /std:c11 "' + (Join-Path $root 'main.c') + '" "' + (Join-Path $root 'scanner.c') + '" "' + (Join-Path $root 'parser.c') + '" /Fe:"' + $exe + '"'
  & cmd.exe /c $compile
  if ($LASTEXITCODE -ne 0) { throw "Compilation failed with exit code $LASTEXITCODE." }

  function Write-Input([string]$Name, [string]$Text) {
    $path = Join-Path $temp $Name
    $bytes = [Text.Encoding]::ASCII.GetBytes($Text)
    [IO.File]::WriteAllBytes($path, $bytes)
    if ($bytes.Length -gt 0 -and $bytes[$bytes.Length - 1] -eq 0) {
      throw "$Name unexpectedly has a trailing NUL byte."
    }
    return $path
  }

  function Check-Output([string]$Name, [string]$InputFile, [string]$Expected) {
    $errorFile = Join-Path $temp 'stderr.txt'
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    Push-Location $temp
    try { $output = & $exe $InputFile 2> $errorFile; $code = $LASTEXITCODE }
    finally { Pop-Location; $ErrorActionPreference = $old }
    $actual = (($output | ForEach-Object { "$_" }) -join [Environment]::NewLine)
    if ($code -ne 0 -or $actual -ne $Expected) {
      throw "$Name failed: exit $code, output [$actual], expected [$Expected]."
    }
    Write-Host "PASS: $Name"
  }

  $empty = Write-Input 'empty.asm' ''
  Check-Output 'empty file with zero bytes' $empty ''
  $normal = Write-Input 'normal.asm' ("mov reg1, 10" + $nl)
  Check-Output 'normal file without trailing NUL' $normal '00001010'
  $noNewline = Write-Input 'no-final-newline.asm' 'mov reg1, 2'
  Check-Output 'file without a trailing newline or NUL' $noNewline '00000010'
  Write-Host 'All EOF regression tests passed.'
}
finally { Remove-Item -LiteralPath $temp -Recurse -Force }

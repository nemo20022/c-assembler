$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('assembler-ram-' + [guid]::NewGuid().ToString('N'))
$exe = Join-Path $temp 'assembler.exe'
New-Item -ItemType Directory -Path $temp | Out-Null

try {
  $vcvars = 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat'
  $compile = 'cd /d "' + $temp + '" && call "' + $vcvars + '" >NUL && cl /nologo /W4 /std:c11 "' +
    (Join-Path $root 'main.c') + '" "' + (Join-Path $root 'scanner.c') + '" "' +
    (Join-Path $root 'parser.c') + '" /Fe:"' + $exe + '"'
  & cmd.exe /c $compile
  if ($LASTEXITCODE -ne 0) { throw "Compilation failed with exit code $LASTEXITCODE." }

  function Write-AssemblyFile([string]$Text) {
    $inputFile = Join-Path $temp 'input.asm'
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($Text + [char]0)
    [System.IO.File]::WriteAllBytes($inputFile, $bytes)
    return $inputFile
  }

  function Invoke-Assembler([string]$Text) {
    $inputFile = Write-AssemblyFile $Text
    $errorFile = Join-Path $temp 'stderr.txt'
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & $exe $inputFile 2> $errorFile
    $code = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    return @{
      Code = $code
      Output = (($output | ForEach-Object { "$_" }) -join [Environment]::NewLine)
      Error = if (Test-Path $errorFile) { Get-Content $errorFile -Raw } else { '' }
    }
  }

  function Assert-Output([string]$Name, [string]$Source, [string]$Expected) {
    $result = Invoke-Assembler $Source
    if ($result.Code -ne 0 -or $result.Output -ne $Expected) {
      throw "FAIL: $Name. Exit $($result.Code), output [$($result.Output)], expected [$Expected]."
    }
    Write-Host "PASS: $Name"
  }

  function Assert-Rejected([string]$Name, [string]$Source) {
    $result = Invoke-Assembler $Source
    if ($result.Code -eq 0) { throw "FAIL: $Name was accepted." }
    Write-Host "PASS: $Name (rejected)"
  }

  Assert-Output 'RAM write byte' "mov [reg2], reg1`n" '11000001'
  Assert-Output 'RAM read byte' "mov reg1, [reg2]`n" '11000000'
  Assert-Rejected 'RAM write with wrong address register' "mov [reg1], reg1`n"
  Assert-Rejected 'RAM write with wrong value register' "mov [reg2], reg3`n"
  Assert-Rejected 'RAM read with wrong destination register' "mov reg3, [reg2]`n"
  Assert-Rejected 'RAM read with wrong address register' "mov reg1, [reg3]`n"
  Assert-Rejected 'missing closing RAM bracket' "mov reg1, [reg2`n"
  Assert-Rejected 'missing comma in RAM write' "mov [reg2] reg1`n"
  Assert-Output 'register-to-register MOV remains unchanged' "mov reg6, reg2`n" '10010110'
  Assert-Output 'constant loading remains unchanged' "mov reg1, 10`n" '00001010'

  Write-Host 'All RAM tests passed.'
}
finally {
  Remove-Item -LiteralPath $temp -Recurse -Force
}
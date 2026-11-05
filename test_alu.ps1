$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('assembler-alu-' + [guid]::NewGuid().ToString('N'))
$exe = Join-Path $temp 'assembler.exe'
$nl = [Environment]::NewLine
$script:inputNumber = 0
New-Item -ItemType Directory -Path $temp | Out-Null
try {
  $vcvars = 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat'
  $compile = 'cd /d "' + $temp + '" && call "' + $vcvars + '" >NUL && cl /nologo /W4 /std:c11 "' + (Join-Path $root 'main.c') + '" "' + (Join-Path $root 'scanner.c') + '" "' + (Join-Path $root 'parser.c') + '" /Fe:"' + $exe + '"'
  & cmd.exe /c $compile
  if ($LASTEXITCODE -ne 0) { throw "Compilation failed with exit code $LASTEXITCODE." }
  function Write-Asm([string]$Text, [string]$Name = '') {
    $script:inputNumber++
    if (!$Name) { $Name = 'input' + $script:inputNumber + '.asm' }
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
  function Check([string]$Name, [string]$Source, [string]$Expected, [string]$Mode = 'positional') {
    $file = Write-Asm $Source
    $arguments = if ($Mode -eq 'flag') { @('-f', $file) } elseif ($Mode -eq 'default') { @() } else { @($file) }
    $result = Run-Asm $arguments
    if ($result.Code -ne 0 -or $result.Output -ne $Expected) { throw ("FAIL " + $Name + ": output [" + $result.Output + "] code " + $result.Code + ", expected [" + $Expected + "]") }
    Write-Host "PASS: $Name"
  }
  function Reject([string]$Name, [string]$Source) {
    $file = Write-Asm $Source
    $result = Run-Asm @($file)
    if ($result.Code -eq 0) { throw ("FAIL " + $Name + ": invalid operands were accepted") }
    Write-Host "PASS: $Name rejected"
  }

  $example = Write-Asm ("mov reg1, 4" + $nl) 'example.asm'
  Check 'default filename and CLI behavior' ("mov reg1, 4" + $nl) '00000100' 'default'

  $operations = @(
    @{ Name = 'OR';  Word = 'or';   Code = 0; Expected = '01011000' },
    @{ Name = 'ADD'; Word = 'add';  Code = 1; Expected = '01011001' },
    @{ Name = 'SUB'; Word = 'sub';  Code = 2; Expected = '01011010' },
    @{ Name = 'NAND';Word = 'nand'; Code = 3; Expected = '01011011' },
    @{ Name = 'AND'; Word = 'and';  Code = 4; Expected = '01011100' },
    @{ Name = 'XOR'; Word = 'xor';  Code = 6; Expected = '01011110' },
    @{ Name = 'EQ';  Word = 'eq';   Code = 7; Expected = '01011111' }
  )
  $index = 0
  foreach ($operation in $operations) {
    $mode = if (($index++ % 2) -eq 0) { 'positional' } else { 'flag' }
    Check ($operation.Name + ' byte with reg1, reg2 sources and reg3 destination') ($operation.Word + " reg1, reg2, reg3" + $nl) $operation.Expected $mode
  }

  $destinations = @(
    @{ Register = 'reg1'; Expected = '01001001' },
    @{ Register = 'reg2'; Expected = '01010001' },
    @{ Register = 'reg3'; Expected = '01011001' },
    @{ Register = 'reg4'; Expected = '01100001' },
    @{ Register = 'reg5'; Expected = '01101001' },
    @{ Register = 'reg6'; Expected = '01110001' }
  )
  foreach ($destination in $destinations) {
    Check ('ADD destination ' + $destination.Register) ("add reg1, reg2, " + $destination.Register + $nl) $destination.Expected
  }

  Reject 'wrong first ALU source' ("or reg2, reg2, reg3" + $nl)
  Reject 'wrong second ALU source' ("add reg1, reg3, reg3" + $nl)
  Reject 'invalid destination register' ("sub reg1, reg2, reg7" + $nl)
  Reject 'non-register ALU operand' ("nand reg1, 2, reg3" + $nl)
  Reject 'missing destination register' ("and reg1, reg2," + $nl)

  Check 'ordinary register MOV unchanged' ("mov reg6, reg2" + $nl) '10010110'
  Check 'constant expansion unchanged' ("mov reg6, 10" + $nl) ("00001010" + $nl + '10001110')
  Check 'semicolon comments unchanged' ("; comment" + $nl + "mov reg1, 3 ; trailing" + $nl) '00000011'
  Check 'NOT unchanged' ("not reg2, reg1" + $nl) '01010101'
  Check 'RAM read unchanged' ("mov reg1, [reg2]" + $nl) '11000000'
  Check 'RAM write unchanged' ("mov [reg2], reg1" + $nl) '11000001'
  Write-Host 'All ALU tests passed.'
}
finally { Remove-Item -LiteralPath $temp -Recurse -Force }
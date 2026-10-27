<#
.SYNOPSIS
    一条命令重跑三份 timing fixture，与 W3 基线逐字节比较。

.DESCRIPTION
    在 tcl-practice 的任何子目录下都能运行（所有路径从 $PSScriptRoot 推出来，
    不依赖当前工作目录，也不会再出现 "..\..\.w4-baseline 找不到" 这类路径错）。

    判据是两个退出码，不是"屏幕上看起来一样"：
      script_exit  解析器自己的退出码，期望 normal=0 / clean=0 / malformed=2
      fc_exit      0 = 逐字节一致
                   1 = 文件能读但内容不同（解析器输出变了）
                   2 = 文件打不开（路径错或基线缺失，与解析器无关）

    注意：$LASTEXITCODE 会被每一条原生命令覆盖，所以本脚本严格按
    "先取 python 的退出码 -> 再跑 fc -> 再取 fc 的退出码" 的顺序，中间不插别的命令。

    输出文件写到 out\verify\；.gitignore 里已经有 out/，不会污染 git status。

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\tests\verify_baseline.ps1
#>

$ErrorActionPreference = 'Stop'

$testsDir = $PSScriptRoot
$root     = Split-Path -Parent $testsDir                       # ...\tcl-practice
$workRoot = Split-Path -Parent $root                           # ...\question
$baseDir  = Join-Path $workRoot '.w4-baseline'
$tclsh    = Join-Path $workRoot 'tools\tclsh.py'
$parser   = Join-Path $root 'report_summary.tcl'
$outDir   = Join-Path $root 'out\verify'

foreach ($p in @($baseDir, $tclsh, $parser)) {
    if (-not (Test-Path $p)) { throw "找不到：$p" }
}
$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) { throw '找不到 python，请确认它在 PATH 里' }

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# 每加一个变体 fixture（W4 第 5 项），在这里加一行，Expect 写它应该的退出码
$cases = @(
    [pscustomobject]@{ Name = 'timing_normal';    Expect = 0 }
    [pscustomobject]@{ Name = 'timing_clean';     Expect = 0 }
    [pscustomobject]@{ Name = 'timing_malformed'; Expect = 2 }
)

"repo    : $root"
"baseline: $baseDir"
"python  : $($py.Source)"
''

$rows = @()
$nBad = 0

foreach ($c in $cases) {
    $rpt  = Join-Path $root   "fixtures\$($c.Name).rpt"
    $out  = Join-Path $outDir "$($c.Name).txt"
    $base = Join-Path $baseDir "$($c.Name).txt"

    # 1) 跑解析器，按行抓 stdout，并立刻取它自己的退出码
    $lines      = @(& python $tclsh $parser $rpt)
    $scriptExit = $LASTEXITCODE

    # 2) 写成 UTF-16LE + CRLF，和基线文件同款编码行尾；否则 fc 会因编码差异报"不同"
    [System.IO.File]::WriteAllLines($out, $lines, [System.Text.Encoding]::Unicode)

    # 3) 逐字节比较；fc 的退出码才是判据（0/1/2 三种含义见文件头）
    $null = & fc.exe /b $out $base
    $fcExit = $LASTEXITCODE

    $ok = ($scriptExit -eq $c.Expect) -and ($fcExit -eq 0)
    if (-not $ok) { $nBad++ }

    $rows += [pscustomobject]@{
        case        = $c.Name
        script_exit = $scriptExit
        expect      = $c.Expect
        fc_exit     = $fcExit
        verdict     = $(if ($ok) { 'OK' } else { 'FAIL' })
    }
}

$rows | Format-Table -AutoSize

if ($nBad -eq 0) {
    "PASS: $($cases.Count)   FAIL: 0"
    exit 0
}

"PASS: $($cases.Count - $nBad)   FAIL: $nBad"
'排查提示：'
'  script_exit 不对 -> 解析器自己的退出码逻辑（0 成功 / 1 用法或文件错 / 2 数据有问题）'
'  fc_exit = 1     -> 内容真的变了，手工跑一次 fc.exe /b 看差异行'
'  fc_exit = 2     -> 路径没找到或基线缺失，和解析器无关'
exit 1

#!/usr/bin/env tclsh
###############################################################################
# run_tests.tcl —— W3 自动测试（一条命令跑完，失败时退出码非 0）
#
# 用法（在 tcl-practice/ 目录下）：
#     tclsh tests/run_tests.tcl
#     tclsh tests/run_tests.tcl -compact      # 只打印结果行，便于 diff
# Windows 上没有 tclsh 时：
#     python ..\tools\tclsh.py tests/run_tests.tcl
#
# 它做的事：
#   1. 用 solutions/ 下的参考实现跑 fixtures/ 里的三份数据；
#   2. 断言退出码 + 关键字段（不用肉眼判断）；
#   3. 输出 PASS/FAIL 汇总，有失败就 exit 1。
#
# 你自己的解析器写好之后，把 $SCRIPT_SUMMARY / $SCRIPT_LOG 改成你的文件名，
# 或者直接删掉 solutions/ 里的参考实现再用同名文件覆盖。
###############################################################################

# 找 tclsh：优先用环境变量 TCLSH，其次找 PATH 里的 tclsh，
# 最后回退到 Python 承载的 tclsh.py（Windows 常用）。
proc find_tclsh {} {
    if {[info exists ::env(TCLSH)] && $::env(TCLSH) ne ""} {
        return [list $::env(TCLSH)]
    }
    if {[llength [auto_execok tclsh]] > 0} {
        return [auto_execok tclsh]
    }
    # 回退：python <repo>/tools/tclsh.py
    set py [auto_execok python]
    set here [file normalize [file dirname [info script]]]
    set cand [file normalize [file join $here .. .. tools tclsh.py]]
    if {[llength $py] > 0 && [file exists $cand]} {
        return [concat $py [list $cand]]
    }
    error "找不到 tclsh。请设置环境变量 TCLSH，或安装 Tcl（apt install tcl）。"
}

set compact 0
if {[llength $argv] > 0 && [lindex $argv 0] eq "-compact"} { set compact 1 }

set here      [file normalize [file dirname [info script]]]
set root      [file normalize [file join $here ..]]
set fixtures  [file join $root fixtures]
set solutions [file join $root solutions]
set runner    [find_tclsh]

set n_pass 0
set n_fail 0
set failures {}

# ---------------------------------------------------------------- 断言工具
proc report {name ok detail} {
    global n_pass n_fail failures compact
    if {$ok} {
        incr n_pass
        if {!$compact} { puts "  \[PASS\] $name" }
    } else {
        incr n_fail
        lappend failures [list $name $detail]
        puts "  \[FAIL\] $name"
        if {!$compact} { puts "         $detail" }
    }
}

# 执行一条命令，返回 {exitcode stdout stderr}
proc run_cmd {cmd} {
    set outfile [file join [file dirname [info script]] _stdout.tmp]
    set errfile [file join [file dirname [info script]] _stderr.tmp]
    set rc [catch {
        exec {*}$cmd > $outfile 2> $errfile
    } err]
    # exec 在退出码非 0 时会抛错，这里要区分「命令跑失败」和「命令不存在」
    set code 0
    if {$rc} {
        if {[regexp {CHILDSTATUS\s+\d+\s+(\d+)} $::errorCode -> c]} {
            set code $c
        } else {
            return [list -1 "" $err]
        }
    }
    set fh [open $outfile r]; set out [read $fh]; close $fh
    set fh [open $errfile r]; set errtxt [read $fh]; close $fh
    file delete -force $outfile $errfile
    return [list $code $out $errtxt]
}

# 从输出里取 "KEY: value" 的值
proc field {text key} {
    foreach line [split $text "\n"] {
        if {[string match "$key:*" $line]} {
            return [string trim [string range $line [expr {[string length $key] + 1}] end]]
        }
    }
    return ""
}
proc slurp {path} {
    set fh [open $path r]
    set data [read $fh]
    close $fh
    return $data
}
# ---------------------------------------------------------------- 测试用例
puts "runner : $runner"
puts "fixtures: $fixtures"
puts ""

puts "== log_summary.tcl =="
set script [file join $root log_summary.tcl]

# 1) 正常日志：25 条（19 PASS / 5 FAIL / 1 SKIP），有 FAIL 所以退出码 2
lassign [run_cmd [concat $runner [list $script [file join $fixtures test_run.log]]]] rc out err
report "正常日志 退出码=2" [expr {$rc == 2}] "实际 rc=$rc"
report "正常日志 PASS=19" [regexp {PASS\s*:\s*19} $out] "输出: $out"
report "正常日志 FAIL=5"  [regexp {FAIL\s*:\s*5} $out] "输出: $out"
report "正常日志 列出失败用例" [regexp {tc_uart_baud_mismatch} $out] "输出: $out"

# 2) 文件不存在：退出码 1，且要有明确提示
lassign [run_cmd [concat $runner [list $script [file join $fixtures no_such.log]]]] rc out err
report "文件不存在 退出码=1" [expr {$rc == 1}] "实际 rc=$rc ; stderr=$err"
report "文件不存在 报错信息" [regexp -nocase {no_such\.log|找不到|couldn't} "$out$err"] "stderr=$err"

# 3) 无参数：退出码 1（用法提示）
lassign [run_cmd [concat $runner [list $script]]] rc out err
report "缺参数 退出码=1" [expr {$rc == 1}] "实际 rc=$rc ; stderr=$err"

puts ""
puts "== report_summary.tcl =="
set script [file join $root report_summary.tcl]

# 4) 正常报告：WNS=-0.483 TNS=-0.757 违例=3 最差路径已填
lassign [run_cmd [concat $runner [list $script [file join $fixtures timing_normal.rpt]]]] rc out err
report "正常报告 退出码=0" [expr {$rc == 0}] "实际 rc=$rc ; stderr=$err"
report "正常报告 DESIGN" [string equal [field $out DESIGN] "timer_uart_top"] "DESIGN=[field $out DESIGN]"
report "正常报告 WNS=-0.483" [string equal [field $out WNS] "-0.483"] "WNS=[field $out WNS]"
report "正常报告 TNS=-0.757" [string equal [field $out TNS] "-0.757"] "TNS=[field $out TNS]"
report "正常报告 VIOLATIONS=3" [string equal [field $out VIOLATIONS] "3"] "VIOLATIONS=[field $out VIOLATIONS]"
report "正常报告 最差路径起点" [regexp {WORST_PATH:\s+u_core/reg_shift_q\[0\] -> u_core/reg_shift_q\[5\]} $out] "WORST_PATH=[field $out WORST_PATH]"

# 5) 无违例报告：WNS=TNS=0，VIOLATIONS=0
lassign [run_cmd [concat $runner [list $script [file join $fixtures timing_clean.rpt]]]] rc out err
report "无违例 退出码=0" [expr {$rc == 0}] "实际 rc=$rc"
report "无违例 WNS=0.000" [string equal [field $out WNS] "0.000"] "WNS=[field $out WNS]"
report "无违例 TNS=0.000" [string equal [field $out TNS] "0.000"] "TNS=[field $out TNS]"
report "无违例 VIOLATIONS=0" [string equal [field $out VIOLATIONS] "0"] "VIOLATIONS=[field $out VIOLATIONS]"

# 6) 坏数据：必须退出码 2，且统计到无效路径
lassign [run_cmd [concat $runner [list $script [file join $fixtures timing_malformed.rpt]]]] rc out err
report "坏数据 退出码=2" [expr {$rc == 2}] "实际 rc=$rc ; stderr=$err"
report "坏数据 INVALID>0" [expr {[field $out INVALID] ne "" && [field $out INVALID] > 0}] "INVALID=[field $out INVALID]"

#表驱体
puts ""
puts "== 变体(格式容错) =="
set vdir [file join $fixtures variants]
set outcsv [file join $root out _test.csv]
set vcases {
    {v_canonical.rpt            0 1 0}
    {v_unit_ns.rpt              0 1 0}
    {v_slack_case.rpt           0 2 0}
    {v_missing_slack_mid.rpt    2 1 1}
    {v_missing_endpoint.rpt     2 0 1}
    {v_na.rpt                   2 0 1}
    {v_plus_sign.rpt            0 1 0}
    {v_thousand.rpt             2 0 1}
    {v_multi_space.rpt          0 1 0}
}

foreach c $vcases {
    lassign $c name eexit epaths einvalid
    lassign [run_cmd [concat $runner [list $script [file join $vdir $name] $outcsv]]] rc out err
    report "变体 $name 退出码=$eexit" [expr {$rc == $eexit}] "实际 rc=$rc ; stderr=$err"
    report "变体 $name PATHS=$epaths"  [string equal [field $out PATHS] $epaths]   "PATHS=[field $out PATHS]"
    report "变体 $name INVALID=$einvalid" [string equal [field $out INVALID] $einvalid] "INVALID=[field $out INVALID]"
}
puts ""
puts "== 批量目录 =="
set batchcsv [file join $root out _batch.csv]
lassign [run_cmd [concat $runner [list $script $fixtures $batchcsv]]] rc out err

report "批量 退出码=2（含 malformed）" [expr {$rc == 2}] "实际 rc=$rc ; stderr=$err"
report "批量 TOTAL 行" [regexp {TOTAL:\s*3 files,\s*3 violations,\s*3 invalid} $out] "输出: $out"

set lines [split [string trim [slurp $batchcsv]] "\n"]
report "批量 CSV 行数=4" [expr {[llength $lines] == 4}] "实际 [llength $lines] 行"
report "批量 CSV 表头 8 列" [expr {[llength [split [lindex $lines 0] ,]] == 8}] "表头=[lindex $lines 0]"
report "批量 CSV 按文件名排序" [expr {[lindex [split [lindex $lines 1] ,] 0] eq "timing_clean.rpt"}] "第 2 行=[lindex $lines 1]"

puts ""
puts "== 错误路径 =="
set emptydir [file join $root out _empty_dir]
file mkdir $emptydir
lassign [run_cmd [concat $runner [list $script $emptydir]]] rc out err
report "空目录 退出码=1" [expr {$rc == 1}] "实际 rc=$rc"
file delete -force $emptydir

lassign [run_cmd [concat $runner [list $script [file join $fixtures no_such_dir]]]] rc out err
report "目录不存在 退出码=1" [expr {$rc == 1}] "实际 rc=$rc"
# ---------------------------------------------------------------- 汇总
puts ""
puts "=================================================="
puts "PASS: $n_pass   FAIL: $n_fail"
if {$n_fail > 0} {
    puts "失败项:"
    foreach f $failures { puts "  - [lindex $f 0]" }
    exit 1
}
puts "全部通过"
exit 0

#!/usr/bin/env tclsh
###############################################################################
# log_summary.tcl —— 参考实现（先自己写，卡住了再对照）
#
# 用途：读取测试日志，统计 PASS/FAIL，列出失败用例。
# 用法：tclsh log_summary.tcl <日志文件>
# 退出码：0 成功；1 用法/文件错误；2 日志里有未知状态
#
# 日志行格式：
#   2026-10-15 09:12:03 INFO  tc_reset_smoke         PASS  12
#   日期        时间      级别  用例名                 结果  耗时
###############################################################################

proc usage {} {
    puts stderr "用法: tclsh log_summary.tcl <日志文件>"
    puts stderr "示例: tclsh log_summary.tcl fixtures/test_run.log"
}

# ---------------------------------------------------------------- 参数检查
if {$argc != 1} {
    usage
    exit 1
}
set logfile [lindex $argv 0]
if {![file exists $logfile]} {
    puts stderr "错误: 找不到文件 \"$logfile\""
    exit 1
}
if {[file size $logfile] == 0} {
    puts stderr "错误: 文件 \"$logfile\" 是空文件"
    exit 1
}

# ---------------------------------------------------------------- 逐行解析
# 用一条正则把 6 个字段全部抓出来，避免 split 后被多个空格坑到。
set re {^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})\s+(\S+)\s+(\S+)\s+(PASS|FAIL|SKIP)\s+(\d+)\s*$}

set total    0
set n_pass   0
set n_fail   0
set n_skip   0
set n_bad    0
set failed   {}   ;# {{用例名 耗时 时间} ...}
set badlines {}   ;# {{行号 原文} ...}

set fh [open $logfile r]
set lineno 0
while {[gets $fh line] >= 0} {
    incr lineno
    set line [string trim $line]
    if {$line eq "" || [string match "#*" $line]} { continue }

    if {![regexp $re $line -> date tm level tcase status ms]} {
        incr n_bad
        lappend badlines [list $lineno $line]
        continue
    }

    switch -- $status {
        PASS { incr n_pass }
        FAIL { incr n_fail ; lappend failed [list $tcase $ms $tm] }
        SKIP { incr n_skip }
        default {
            incr n_bad
            lappend badlines [list $lineno $line]
        }
    }
}
close $fh

set total [expr {$n_pass + $n_fail + $n_skip}]

# ---------------------------------------------------------------- 输出
puts "===== 日志汇总: [file tail $logfile] ====="
puts [format "总用例数 : %d" $total]
puts [format "PASS     : %d" $n_pass]
puts [format "FAIL     : %d" $n_fail]
puts [format "SKIP     : %d" $n_skip]
if {$n_bad > 0} {
    puts [format "无法解析 : %d 行" $n_bad]
}

if {[llength $failed] > 0} {
    puts ""
    puts "失败用例（按用例名排序）:"
    foreach rec [lsort -index 0 $failed] {
        lassign $rec tcase ms tm
        puts [format "  %-24s 耗时 %6s ms   首次失败时间 %s" $tcase $ms $tm]
    }
}

if {$n_bad > 0} {
    puts ""
    puts "格式异常的行:"
    foreach rec $badlines {
        lassign $rec no text
        puts [format "  第 %d 行: %s" $no $text]
    }
}

# 有 FAIL 时也给非零退出码，方便接进 CI
if {$n_fail > 0 || $n_bad > 0} {
    exit 2
}
exit 0

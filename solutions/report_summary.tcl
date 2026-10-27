#!/usr/bin/env tclsh
###############################################################################
# report_summary.tcl —— 参考实现（先自己写，卡住了再对照）
#
# 用途：解析 mock 时序报告，输出设计名、WNS、TNS、违例数、最差路径。
# 用法：tclsh report_summary.tcl <时序报告> [更多报告...]
# 退出码：0 成功；1 用法/文件错误；2 报告中存在无效路径（字段缺失或非数字）
#
# 输出格式（tests/run_tests.tcl 依赖这些字段名，不要改）：
#   FILE: <文件名>
#   DESIGN: <设计名>
#   CORNER: <工艺角>
#   WNS: <最差负 slack，无违例输出 0.000>
#   TNS: <所有负 slack 之和，无违例输出 0.000>
#   VIOLATIONS: <slack < 0 的路径数>
#   WORST_PATH: <起点> -> <终点>  slack=<值>
#   PATHS: <解析到的路径总数>
#   INVALID: <字段缺失或非法的路径数>
###############################################################################

proc usage {} {
    puts stderr "用法: tclsh report_summary.tcl <时序报告> \[更多报告...\]"
}

if {$argc < 1} {
    usage
    exit 1
}

# ---------------------------------------------------------------- 单文件解析
# 返回 list：{design corner paths violations wns tns worst_start worst_end worst_slack invalid}
proc parse_report {path} {
    if {![file exists $path]} {
        error "找不到文件 \"$path\""
    }
    set fh [open $path r]
    set content [read $fh]
    close $fh

    if {[string trim $content] eq ""} {
        error "文件 \"$path\" 是空文件"
    }

    # 设计名 / 工艺角从报告头部的注释里取：#  设计: xxx   工艺角: xxx
    set design "UNKNOWN"
    set corner "UNKNOWN"
    if {[regexp {#\s*设计:\s*(\S+)} $content -> d]} { set design $d }
    # 注意：正则里字面量竖线要转义成 \| ，否则会被当成「或」
    if {[regexp {#\s*工艺角:\s*(\S+)} $content -> c]} { set corner $c }
    # 以 "Startpoint:" 为分界，把报告切成一条条路径
    set blocks {}
    set cur {}
    foreach line [split $content "\n"] {
        if {[string match "Startpoint:*" $line]} {
            if {[llength $cur] > 0} { lappend blocks $cur }
            set cur [list $line]
        } elseif {[llength $cur] > 0} {
            lappend cur $line
        }
    }
    if {[llength $cur] > 0} { lappend blocks $cur }

    set n_valid 0
    set n_invalid 0
    set viol 0
    set wns 0.0
    set tns 0.0
    set worst_slack 0.0
    set worst_start ""
    set worst_end ""

    foreach block $blocks {
        set text [join $block "\n"]

        # Startpoint / Endpoint 后面紧跟的那一行才是真正的名字
        set start ""
        set end ""
        if {[regexp -line {^Startpoint:\s*(\S+)} $text -> s]} { set start $s }
        if {[regexp -line {^Endpoint:\s*(\S+)} $text -> e]} { set end $e }

        # slack 行形如：  slack (VIOLATED)   -0.483
        if {![regexp -line {^\s*slack\s+\(\w+\)\s+(\S+)\s*$} $text -> slackstr]} {
            incr n_invalid
            continue
        }
        if {![string is double -strict $slackstr]} {
            incr n_invalid
            continue
        }
        if {$start eq "" || $end eq ""} {
            incr n_invalid
            continue
        }

        set slack [expr {double($slackstr)}]
        incr n_valid
        if {$slack < 0.0} {
            incr viol
            set tns [expr {$tns + $slack}]
        }
        if {$slack < $worst_slack} {
            set worst_slack $slack
            set worst_start $start
            set worst_end   $end
        }
    }

    set wns $worst_slack
    if {$viol == 0} { set wns 0.0 ; set tns 0.0 }

    return [list $design $corner $n_valid $viol $wns $tns \
                 $worst_start $worst_end $worst_slack $n_invalid]
}

# ---------------------------------------------------------------- 主流程
set bad 0
foreach path $argv {
    puts "FILE: [file tail $path]"
    if {[catch {parse_report $path} res]} {
        puts stderr "错误: $res"
        exit 1
    }
    lassign $res design corner npaths viol wns tns ws we wslack invalid

    puts "DESIGN: $design"
    puts "CORNER: $corner"
    puts [format "WNS: %.3f" $wns]
    puts [format "TNS: %.3f" $tns]
    puts "VIOLATIONS: $viol"
    if {$viol > 0} {
        puts [format "WORST_PATH: %s -> %s  slack=%.3f" $ws $we $wslack]
    } else {
        puts "WORST_PATH: none"
    }
    puts "PATHS: $npaths"
    puts "INVALID: $invalid"
    puts ""

    if {$invalid > 0} { incr bad }
}

if {$bad > 0} {
    puts stderr "存在 $bad 份含无效路径的报告，退出码 2"
    exit 2
}
exit 0

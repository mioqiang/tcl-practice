# 用途：解析 mock 时序报告，输出设计名、WNS、TNS、违例数、最差路径
# 用法：tclsh report_summary.tcl <时序报告>
# 退出码：0 成功：1 用法/文件错误：2 报告里有无效路径
# 输出：FILE /DESIGN /CORNER /WNS /TNS /VIOLATIONS /WORST_PATH /PATHS /INVALID
###############################################################################

proc usage {} {
    puts stderr "用法: tclsh report_summary.tcl <时序报告> [outfile]"
    puts stderr "示例: tclsh report_summary.tcl fixtures/timing_normal.rpt"
}
if {$argc < 1 || $argc > 2} {
    usage
    exit 1
}
#目录分支里不再 exit，只记 $mode。文件检查放进 else，这样它只对文件生效
set path [lindex $argv 0]
if {$argc >= 2} {
     set summaryFile [lindex $argv 1] } else {
     set summaryFile "out/summary.csv" }
set mode single
if {[file isdirectory $path]} {
    set mode  batch
} else {
   if {![file exists $path]} {
    puts stderr "Error:路径 \"$path\" 不存在"
    exit 1
    }
    if {[file size $path] == 0} {
    puts stderr "Error:路径 \"$path\" 存在但为空"
    exit 1
    }
}


# dict {design corner records invalid}
#文本转结构
proc parse_report {path}   {
    set INVALID 0
    set fh [open $path r]
    set cur_start ""
    set cur_end ""
    set DESIGN UNKNOWN
    set CORNER UNKNOWN
    set records {}
while {[gets $fh line] >= 0} {
    set line [string trim $line]
    if {[regexp {^Startpoint:\s+(\S+)} $line -> v]} {
        if {$cur_start ne ""} { incr INVALID}
        set cur_start $v
        set cur_end ""
    } elseif {[regexp {^Endpoint:\s+(\S+)} $line -> v]} {
        set cur_end $v
    } elseif {[regexp -nocase {slack\s+\((?:MET|VIOLATED)\)\s+(\S+)} $line -> raw]} {
        set v [regsub {[A-Za-z]+$} $raw ""]
        if {$cur_start ne "" && $cur_end ne "" && [string is double -strict $v]} {
                lappend records [list $cur_start $cur_end $v]
        } else {
            incr INVALID
        }
        set cur_start ""
        set cur_end ""
    }
    if {[regexp {设计:\s+(\S+)} $line -> v]} {set DESIGN $v}
    if {[regexp {工艺角:\s+(\S+)} $line -> v]} {set CORNER $v}
}
if {$cur_start ne ""} {
    incr INVALID
}
close $fh
return [dict create design $DESIGN corner $CORNER records $records invalid $INVALID] }

#结构转指标
proc compute_summary {report} {
    set wns 0.0
    set tns 0.0
    set violations 0
    set worst_start ""
    set worst_end ""
    foreach rec [dict get $report records] {
        lassign $rec start end slack
            if {$slack < 0} {
            incr violations
            set tns [expr {$tns + $slack}]
            if {$slack < $wns} {
                set wns $slack
                set worst_start $start
                set worst_end $end
            }
        }
    }
    return [dict create wns $wns tns $tns violations $violations \
                         worst_start $worst_start worst_end $worst_end \
                         paths [llength [dict get $report records]]]
}

#指标变表
proc format_row {path rep summary} {
    set design [dict get $rep design]
    set corner [dict get $rep corner]
    set wns [format %.3f [dict get $summary wns]]
    set tns [format %.3f [dict get $summary tns]]
    set violations [dict get $summary violations]
    set worst_start [dict get $summary worst_start]
    set worst_end [dict get $summary worst_end]
    set fiile [file tail $path]
    return [list $fiile $design $corner $wns $tns $violations $worst_start $worst_end]
}

#表转文件
proc write_csv {outfile rows} {
    file mkdir [file dirname $outfile]
    set fh [open $outfile w]
    set header [list file design corner wns tns violations worst_start worst_end]
    puts $fh [join $header ,]
    foreach row $rows {
        puts $fh [join $row ,]
    }
    close $fh
}
# set files [lsort $files]
#     puts "MODE: batch"
#     puts "DIR: $path"
#     puts "FILES: [llength $files]"
#     foreach f $files {puts $f}
#     exit 0

if {$mode eq "batch"} {
    set files [glob -nocomplain [file join $path *.rpt]]
    if {[llength $files] == 0} {
        puts stderr "Error: 目录 \"$path\" 里没有 .rpt 文件"
        exit 1
    }
    puts "MODE: batch"
    puts "DIR: $path"
    puts [format "%-28s %6s %11s %9s %9s" FILE PATHS VIOLATIONS WNS TNS]
    set rows {}
    set totalviol 0
    set totalInvalid 0
    foreach f $files {
        set rep [parse_report $f]
        set summary [compute_summary $rep]
        lappend rows [format_row $f $rep $summary]
        puts [format "%-28s %6d %11d %9.3f %9.3f" [file tail $f] [dict get $summary paths] [dict get $summary violations] [dict get $summary wns] [dict get $summary tns]]
        incr totalviol [dict get $summary violations]
        incr totalInvalid [dict get $rep invalid]
    }
    write_csv $summaryFile $rows
    puts [format "TOTAL: %d files, %d violations, %d invalid" [llength $files] $totalviol $totalInvalid]
    exit [expr {$totalInvalid > 0 ? 2 : 0}]
}

set rep [parse_report $path]
set summary [compute_summary $rep]
puts "FILE: [file tail $path]"
puts "DESIGN: [dict get $rep design]"
puts "CORNER: [dict get $rep corner]"
puts "WNS: [format %.3f [dict get $summary wns]]"
puts "TNS: [format %.3f [dict get $summary tns]]"
puts "VIOLATIONS: [dict get $summary violations]"
puts "WORST_PATH: [dict get $summary worst_start] -> [dict get $summary worst_end]  slack = [format %.3f [dict get $summary wns]]"
puts "PATHS: [dict get $summary paths]"
puts "INVALID: [dict get $rep invalid]"


write_csv $summaryFile [list [format_row $path $rep $summary]]

if {[dict get $rep invalid] > 0} {
    exit 2
} else {
    exit 0
}
# 输出：FILE /DESIGN /CORNER /WNS /TNS /VIOLATIONS /WORST_PATH /PATHS /INVALID

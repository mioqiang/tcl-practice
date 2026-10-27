# 用途：解析 mock 时序报告，输出设计名、WNS、TNS、违例数、最差路径
# 用法：tclsh report_summary.tcl <时序报告>
# 退出码：0 成功：1 用法/文件错误：2 报告里有无效路径
# 输出：FILE /DESIGN /CORNER /WNS /TNS /VIOLATIONS /WORST_PATH /PATHS /INVALID
###############################################################################

proc usage {} {
    puts stderr "用法: tclsh report_summary.tcl <时序报告>"
    puts stderr "示例: tclsh report_summary.tcl fixtures/timing_normal.rpt"
}
if {$argc != 1} {
    usage
    exit 1
}

set path [lindex $argv 0]
if {![file exists $path]} {
    puts stderr "Error:路径 \"$path\" 不存在"
    exit 1
}
if {[file size $path] == 0} {
    puts stderr "Error:路径 \"$path\" 存在但为空"
    exit 1
}

# dict {design corner records invalid}
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
        set cur_start $v
        set cur_end ""
    } elseif {[regexp {^Endpoint:\s+(\S+)} $line -> v]} {
        set cur_end $v
    } elseif {[regexp {slack \((?:MET|VIOLATED)\)\s+(\S+)} $line -> v]} {
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

set rep [parse_report $path]
set summary [compute_summary $rep]
puts "FILE: [file tail $path]"
puts "DESIGN: [dict get $rep design]"
puts "CORNER: [dict get $rep corner]"
puts "WNS: [format %.3f [dict get $summary wns]]"
puts "TNS: [format %.3f [dict get $summary tns]]"
puts "VIOLATIONS: [dict get $summary violations]"
puts "WORST_PATH: [dict get $summary worst_start] -> [dict get $summary worst_end]  slack = [format %.3f [dict get $summary wns]]"
puts "INVALID: [dict get $summary invalid]"

if {[dict get $rep invalid] > 0} {
    exit 2
} else {
    exit 0
}
# 输出：FILE /DESIGN /CORNER /WNS /TNS /VIOLATIONS /WORST_PATH /PATHS /INVALID

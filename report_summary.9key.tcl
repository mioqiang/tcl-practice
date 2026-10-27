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
    set PATHS 0
    set VIOLATIONS 0
    set fh [open $path r]
    set cur_start ""
    set cur_end ""
    set WNS 0.0
    set TNS 0.0
    set worst_start ""
    set worst_end ""
    set DESIGN UNKNOWN
    set CORNER UNKNOWN

while {[gets $fh line] >= 0} {
    set line [string trim $line]
    if {[regexp {^Startpoint:\s+(\S+)} $line -> v]} {
        set cur_start $v
        set cur_end ""
    } elseif {[regexp {^Endpoint:\s+(\S+)} $line -> v]} {
        set cur_end $v
    } elseif {[regexp {slack \((?:MET|VIOLATED)\)\s+(\S+)} $line -> v]} {
        if {$cur_start ne "" && $cur_end ne "" && [string is double -strict $v]} {
            incr PATHS
            if {$v < 0} {
                incr VIOLATIONS
                set TNS [expr {$TNS + $v}]
                if {$v < $WNS} {set WNS $v ; set worst_start $cur_start ; set worst_end $cur_end}
            }
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
return [dict create design $DESIGN corner $CORNER wns $WNS tns $TNS violations $VIOLATIONS worst_start $worst_start worst_end $worst_end paths $PATHS invalid $INVALID] }
set rep [parse_report $path]
puts "FILE: [file tail $path]"
puts "DESIGN: [dict get $rep design]"
puts "CORNER: [dict get $rep corner]"
puts "WNS: [format %.3f [dict get $rep wns]]"
puts "TNS: [format %.3f [dict get $rep tns]]"
puts "VIOLATIONS: [dict get $rep violations]"
puts "WORST_PATH: [dict get $rep worst_start] -> [dict get $rep worst_end]  slack = [format %.3f [dict get $rep wns]]"
puts "PATHS: [dict get $rep paths]"
puts "INVALID: [dict get $rep invalid]"

if {[dict get $rep invalid] > 0} {
    exit 2
} else {
    exit 0
}
# 输出：FILE /DESIGN /CORNER /WNS /TNS /VIOLATIONS /WORST_PATH /PATHS /INVALID

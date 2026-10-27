#!/usr/bin/env tclsh
###############################################################################
# 02_list_string.tcl —— 周二练习：list 与 string，解析一行日志
#
# 运行：tclsh 02_list_string.tcl
#(python ..\tools\tclsh.py basics\02_list_string.tcl)
# 数据：fixtures/test_run.log 里的一行就是你的输入
#   set line "2026-10-15 09:12:13 ERROR tc_fifo_overflow       FAIL  120"
###############################################################################

# ---------------------------------------------------------------- 练习 1
# 用 list/llength/lindex/lrange/lappend/lsort/lsearch 各写一行，观察结果。
# TODO: 建一个 list {b a c}，排序后输出；再 lappend 一个元素；再 lsearch 找 "a" 的下标。
# TODO: puts "排序后    : ..."
# TODO: puts "追加后    : ..."
# TODO: puts "a 的下标  : ..."

# fail: set mylist {b a c}
# puts "原始      : $mylist"
# set list [list b a c]
# puts "llength   :[llength $list]"
# puts "[lindex $list 1]"
# puts "[lrange $list 1 end]"
# lappend list d
# puts "新list: $list"
# puts "排序后: [lsort -ascii -increasing $list]"
# puts "查找a元素返回下标: [lsearch $list a]"
set mylist {b a c}
puts "原始      : $mylist"

set mylist2 [list b a c]
puts "llength   : [llength $mylist2]"      ;# 3
puts "lindex    : [lindex $mylist2 1]"     ;# a
puts "lrange    : [lrange $mylist2 1 end]" ;# a c

lappend mylist2 d
puts "追加后    : $mylist2"                ;# b a c d
puts "排序后    : [lsort $mylist2]"        ;# a b c d
puts "查找 a 下标: [lsearch $mylist2 a]"   ;# 1
# ---------------------------------------------------------------- 练习 2
# 把一行日志拆成字段。
# 注意：字段之间可能有多个空格，直接用 split 会拆出一堆空串。
# 要求：返回一个 6 元素 list {date time level case status ms}
#       （提示：regexp 抓组，比 split 稳）
# TODO: 完成 proc parse_line {line} { ... }
proc parse_line {line} {
    set pat {^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})\s+(\S+)\s+(\S+)\s+(PASS|FAIL)\s+(\d+)$}
#    if {[regexp $pat $line date full level case status ms]} #
    if {[regexp $pat $line  -> date time level case status ms]} {
    return [list $date $time $level $case $status $ms]
    } else {
    error "无法解析的行日志 : $line"
    }
}

set sample "2026-10-15 09:12:13 ERROR tc_fifo_overflow       FAIL  120"
set fields [parse_line $sample]
puts "字段数    : [llength $fields]"                ;# 期望 6
puts "级别      : [lindex $fields 2]"               ;# 期望 ERROR
puts "用例      : [lindex $fields 3]"               ;# 期望 tc_fifo_overflow
puts "状态      : [lindex $fields 4]"               ;# 期望 FAIL

# ---------------------------------------------------------------- 练习 3
# 字符串处理：把用例名 tc_fifo_overflow 变成 "Fifo Overflow"。
# 提示：split 按下划线，string totitle 或 string toupper 第一个字符，join 回去。
# TODO: 完成 proc pretty_name {case} { ... }
######fail: proc pretty_name {case} {
#     set list [ split $case _ ]
#     # puts "新列表为 : $list"
#     # puts "新列表元素个数为 : [ llength $list ]"
#     set list [ lreplace $list 0 0 ]
#     #  puts "新列表为 : $list"
#     #  puts "新列表元素个数为 : [ llength $list ]"
#     return [ string totitle $list ]
# }
# puts "美化      : [pretty_name tc_fifo_overflow]"    ;# 期望 Fifo Overflow#####
proc pretty_name {case} {
    set list [ split $case _ ]

    set list [ lreplace $list 0 0 ]
    set words {}
    foreach w $list {
        lappend words [string totitle $w]
    }
    return [ join $words " "]
}
puts "美化      : [pretty_name tc_fifo_overflow]"    ;# 期望 Fifo Overflow;
#foreach + lappend = 转换一个 list（把每个元素变成新样子）
# ---------------------------------------------------------------- 练习 4
# 用字符串操作从路径里取信息（不要用 file 命令，练 string）。
#   "C:/work/timing_normal.rpt"  -> 扩展名 "rpt"、目录 "C:/work"、基本名 "timing_normal"
# TODO: 完成 proc split_path {path} { ... } 返回 {dir base ext}
proc split_path {path} {
    set ext1 [string last / $path]
    set dir1 [string last . $path]
    set ext  [string range $path 0 [expr {$ext1 - 1}]]
    set dir  [string range $path [expr {$dir1 + 1}] end]
    set base [string range $path [expr {$ext1 + 1}] [expr {$dir1 - 1}]]
    # return  " 目录 :$ext \n基本名 :$base \n扩展名 :$dir\n "
     return  [ list $dir $base $ext ]
}
puts "路径拆分  : [split_path C:/work/timing_normal.rpt]"

# 调用处自己决定怎么显示（多行格式）
lassign [split_path C:/work/timing_normal.rpt] d b e
puts "路径拆分  :"
puts "  目录   : $d"
puts "  基本名 : $b"
puts "  扩展名 : $e"

# ---------------------------------------------------------------- 练习 5
# 用 join / split 把 list 变成 CSV 一行。
# TODO: 输出 tc_a,PASS,12
set rec {tc_a PASS 12}
puts "CSV       : [join $rec ,]"

# ---------------------------------------------------------------- 练习 6
# 用 string map 把日志级别统一成小写（Bash 里你会用 tr）。
# TODO: 输出 error
puts "小写级别  : [string map {ERROR error} ERROR]"

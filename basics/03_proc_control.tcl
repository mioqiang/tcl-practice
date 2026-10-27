#!/usr/bin/env tclsh
###############################################################################
# 03_proc_control.tcl —— 周三练习：if / foreach / switch / proc / 作用域
#
# 运行：tclsh 03_proc_control.tcl
# 目标：把「统计 PASS/FAIL」封装成过程，过程之间用参数和返回值通信，
#       不要靠全局变量传结果（这是后面写解析器的分水岭）。
###############################################################################

# ---------------------------------------------------------------- 练习 1
# 用 switch 把日志级别映射成数字（DEBUG=0 INFO=1 WARN=2 ERROR=3），
# 未知级别返回 -1。
# TODO: 完成 proc level_num {level} { ... }
proc level_num {level} {
    switch $level {
        ERROR {
            return "3"
        }
        WARN {
            return "2"
        }
        INFO {
            return "1"
        }
        DEBUG {
            return "0"
        }
        default {
            return "-1"
        }
    }
}
puts "ERROR -> [level_num ERROR]"    ;# 期望 3
puts "WARN  -> [level_num WARN]"     ;# 期望 2
puts "TRACE -> [level_num TRACE]"    ;# 期望 -1

# ---------------------------------------------------------------- 练习 2
# 用 foreach 统计一个结果列表里的 PASS / FAIL 个数。
# 要求：返回 {pass fail}，不修改任何全局变量。
# TODO: 完成 proc count_status {status_list} { ... }
#####################proc count_status {status_list} {
#     foreach  count $status {
#         set count1 [list [lsearch -all $status_list {PASS}]]
#         set count2 [llength $count1]
#         set count3 [list [lsearch -all $status_list {FAIL}]]
#         set count4 [llength $count3]
#     }
#     return "{$count2 $count4}"
##################### }
# puts "统计 : [count_status {PASS FAIL PASS PASS FAIL PASS}]"   ;# 期望 {4 2}
proc count_status {status_list} {
    set np 0
    set nf 0
    foreach  s $status_list {
        switch $s {
            PASS { incr np}
            FAIL { incr nf}
            default {
                # 其它类型值
            }
        }
    }
    return [ list $np $nf ]
}
puts "统计 : [count_status {PASS FAIL PASS PASS FAIL PASS}]"   ;# 期望 {4 2}

# ---------------------------------------------------------------- 练习 3
# 用 for 或 while 生成 1..n 的列表（不用 range 类扩展）。
# TODO: 完成 proc seq_list {n} { ... }
proc seq_list {n} {
    # set 0 { }
    set num { }
    for {set i 1} { $i <= $n } {incr i} {
        lappend num "$i"
    }
    # return "$0"
    return $num
}
puts "seq  : [seq_list 5]"           ;# 期望 {1 2 3 4 5}

# ---------------------------------------------------------------- 练习 4
# 作用域实验：下面这个 proc 想修改外面的计数器，但改不动。
# TODO: (a) 先运行看结果；(b) 用 upvar 1 让它真的能改；(c) 在注释里写出原因。
set hits 0
proc bump_wrong {} {
    set hits 0
    incr hits
    return $hits
}
proc bump_right {varname} {
    upvar 1 $varname var
    incr var
    return $var
}
puts "错误版后 hits = $hits"                      ;# 仍然是 0
puts "正确版返回  = [bump_right hits]"            ;# 期望 1
puts "正确版后 hits = $hits"                      ;# 期望 1

# 计数器：调用者要持续累加
proc count_pass {result varname} {
    upvar 1 $varname n
    if {$result eq "PASS"} { incr n }
}
set np 0
foreach r {PASS FAIL PASS} { count_pass $r np }
puts $np        ;# 2
# ---------------------------------------------------------------- 练习 5
# 用 catch 保护一段会失败的操作，把错误信息和错误码分类打印出来。
# 要求：失败时返回字符串 "ERR:<消息>"，成功时返回 "OK:<结果>"。
# TODO: 完成 proc safe_div {a b} { ... }
# proc safe_div {a b} {
#     catch {expr { a / b}} result1
#     if {b != 0} {
#         return "OK: $result1"
#     } else {

#         return "ERR :除数为0"
#     }
# }
proc safe_div {a b} {
    if {[catch {expr {$a / $b}} result]} {
        return " ERR : $result"
    } else {
        return " OK : $result"
    }
}
puts [safe_div 10 2]      ;# 期望 OK:5
puts [safe_div 10 0]      ;# 期望 ERR:... (除零信息)

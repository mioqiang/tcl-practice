#!/usr/bin/env tclsh
###############################################################################
# 01_basics.tcl —— 周一练习：变量替换 / expr / 引号与花括号
#
# 运行：tclsh 01_basics.tcl      （Windows 上：python ..\tools\tclsh.py 01_basics.tcl）
# 目标：每条 TODO 都写一个能跑的版本，最后用 tests/run_tests.tcl 自动判定。
# 规则：本文件不要看答案，先自己写；报错记到 README 的 bug 区。
###############################################################################

# ---------------------------------------------------------------- 练习 1
# 用 set 定义两个变量，用 expr 计算「华氏度 -> 摄氏度」。
# 公式：c = (f - 32) * 5 / 9，要求结果保留 2 位小数（提示：format）。
# TODO: 写一个 proc f2c {f} { ... }，返回值是字符串，例如 98.6 -> 37.00
proc f2c {f} {
    set c [expr {($f - 32) *5.00 / 9}]
    return [format %.2f $c]
}
puts "f2c(98.6) = [f2c 98.6]"      ;# 期望 37.00
puts "f2c(32)   = [f2c 32]"        ;# 期望 0.00
puts "f2c(212)  = [f2c 212]"       ;# 期望 100.00
puts "f2c(100)  = [f2c 100]"        ;# 期望 37.78
puts "f2c(72)   = [f2c 72]"         ;# 期望 22.22
puts "f2c(0)    = [f2c 0]"          ;# 期望 -17.78

# ---------------------------------------------------------------- 练习 2
# 解释下面两个 puts 的差别，并把观察结果写在注释里（这句话就是周五复盘要交的内容）。
set x 5
puts "双引号: $x + 3 = [expr {$x + 3}]"
puts {花括号: $x + 3 = [expr {$x + 3}]}
# TODO: 用一句话解释为什么花括号那行不替换。
##双引号:   5 + 3 = 8
##花括号:  $x + 3 = [expr {$x + 3}]
##花括号会阻值变量替换
# ---------------------------------------------------------------- 练习 3
# 用 expr 判断闰年：能被 4 整除且不能被 100 整除，或者能被 400 整除。
# 要求返回 1/0（提示：&& || 和 % 运算）。
# TODO: 完成 proc is_leap {year} { ... }
#fail : proc is_leap {year} {
#    if{[(expr {year % 4}) && (expr {year %100})] || [expr (year % 400)]}
#   {return 1}
#    else{return 0}
#}
proc is_leap {year} {
    if {($year % 4 ==0 && $year %100 != 0) || $year % 400 ==0} {
    return 1
    } else {
    return 0
    }
}
puts "is_leap(2024) = [is_leap 2024]"   ;# 期望 1
puts "is_leap(1900) = [is_leap 1900]"   ;# 期望 0
puts "is_leap(2000) = [is_leap 2000]"   ;# 期望 1
puts "is_leap(2026) = [is_leap 2026]"   ;# 期望 0

# ---------------------------------------------------------------- 练习 4
# 写一个简单计算器：输入两个数和一个运算符（+ - * /），返回结果字符串。
# 除数为 0 时必须用 error 抛出异常（不要让脚本直接崩）。
# TODO: 完成 proc calc {a op b} { ... }
#fail:proc calc {a op b} {
#    switch -- $op {
#        + {
#            return ( expr {$a + $b} )
#       }
#        - {
#            return ( expr {$a - $b} )
#        }
#        * {
#            return ( expr {$a * $b} )
#        }
#        / {
#            if {$b == 0} {
#                error "除数不能为0"
#            } else {
#                return ( expr {$a / $b})
#            }
#        }
#    }
#}
proc calc {a op b} {
    switch -- $op {
        + {
            return [ expr {$a + $b} ]
        }
        - {
            return [ expr {$a - $b} ]
        }
        * {
            return [ expr {$a * $b} ]
        }
        / {
            if {$b == 0} {
                error "除数不能为0"
            } else {
                return [ expr {$a * 1.0 / $b}]
            }
        }
        default { error "不支持的运算符: $op" }
    }
}
puts "calc(6,+,7) = [calc 6 + 7]"      ;# 期望 13
puts "calc(6,/,4) = [calc 6 / 4]"      ;# 期望 1.5
puts "calc(1,/,0) = [calc 1 / 0]"      ;# 期望 error 被 catch 到

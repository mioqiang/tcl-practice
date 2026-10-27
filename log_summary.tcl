# mession: 写一个 log_summary.tcl：读测试日志，统计 PASS/FAIL/SKIP，列出失败用例，用退出码表示健康度
#          退出码：有 FAIL 2 ; 没有 FAIL 0 ; 无参数 / 文件不存在 / 空文件 1
# input: fixtures/test_run.log，每行 6 个字段：2026-10-15  09:12:03  INFO   tc_reset_smoke  PASS  12
# output: PASS: 19
#         FAIL: 5
#         SKIP: 1
#         失败用例: <至少包含 tc_uart_baud_mismatch>
# expert: 19 / 5 / 1，exit=2。

if {$argc != 1} {
    exit 1
}

set path [lindex $argv 0]
if {[file exists $path] eq 0} {
    puts stderr "Error : 路径\"$path\" 不存在"
    exit 1
}
if {[file size $path] eq 0} {
    puts stderr "Error : 路径\"$path\" 存在但为空"
    exit 1
}

set read {^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})\s+(\S+)\s+(\S+)\s+(PASS|FAIL|SKIP)\s+(\d+)$}
set npass 0
set nfail 0
set nskip 0
set bad {}

set fh [open $path r]
while {[gets $fh line] >= 0} {
        if {[regexp $read $line -> date time level tcase status ms]} {
            switch -- $status {
                PASS { incr npass}
                FAIL { incr nfail
                        lappend bad $tcase}
                SKIP { incr nskip}
                default { }
            }
        }
}
close $fh
puts "失败用例: $bad"
puts "PASS: $npass"
puts "FAIL: $nfail"
puts "SKIP: $nskip"

if { $nfail eq 0} {
    exit 0
} else {
    exit 2
}

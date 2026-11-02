#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tclsh.py —— Windows 上不装 Tcl 也能运行 .tcl 脚本（宿主：Python 自带的 Tk/Tcl 8.6）

用法（与真正的 tclsh 一致）：
    python tclsh.py                             # 交互模式 REPL
    python tclsh.py 01_basics.tcl               # 运行脚本
    python tclsh.py log_summary.tcl fixtures/test_run.log   # 运行脚本并传参

为什么需要它：Windows 不自带 tclsh，但 Python 3 的 tkinter 内嵌了完整的 Tcl 8.6.13。
本脚本把 Tcl 的 stdin/stdout/stderr 桥接到 Python 的流，并按 tclsh 的规则设置
argv0 / argv / argc / 脚本退出码，使 `.tcl` 脚本在本机和 Linux 上行为一致。

明确不做的部分（本阶段不需要）：
  - 不支持 Tcl 扩展包（Tcllib / tdbc）和 Tk 图形界面（没有 wish）；
  - exec 由 Python 子进程实现：无 shell 语法糖，需要时写 exec cmd /c "a & b"；
  - 在 Linux / WSL 上请直接用系统 tclsh（sudo apt install tcl）。
"""

import os
import subprocess
import sys

EOF_SENTINEL = "\x00__PYSTDIN_EOF__\x00"

# ------------------------------------------------------------------ Tcl 侧引导
# 整段用 r'''...''' 包住，避免 Python 与 Tcl 的引号/反斜杠互相干扰。
BOOTSTRAP = r'''
# ============ 0. 编码统一为 UTF-8 ============
# Windows 上 Tcl 的 system 编码是 cp936，会把 UTF-8 的 .tcl 源文件读成乱码。
# 脚本、fixture、报告都统一按 UTF-8 处理（Python 侧也是 UTF-8）。
catch {encoding system utf-8}

# ============ 1. stdin / stdout / stderr 桥接到 Python ============
# 原理：把内置 puts/gets 改名，再用同名 proc 覆盖，转发到 Python 回调。
if {[llength [info commands puts]]} { rename ::puts ::__puts_builtin }
if {[llength [info commands gets]]} { rename ::gets ::__gets_builtin }

proc ::puts {args} {
    set nonewline 0
    if {[lindex $args 0] eq "-nonewline"} {
        set nonewline 1
        set args [lrange $args 1 end]
    }
    if {[llength $args] == 1} {
        set chan stdout
        set str  [lindex $args 0]
    } elseif {[llength $args] == 2} {
        set chan [lindex $args 0]
        set str  [lindex $args 1]
    } else {
        return -code error "wrong # args: should be \"puts ?-nonewline? ?channelId? string\""
    }
    # 只有 stdout/stderr 需要桥接到 Python；文件通道交给 Tcl 自己的实现，
    # 否则写文件会静默失败（测试脚本里重定向输出全靠它）。
    if {$chan eq "stdout" || $chan eq "stderr"} {
        __pyputs $chan $str $nonewline
        return ""
    }
    if {$nonewline} {
        return [uplevel 1 [list ::__puts_builtin -nonewline $chan $str]]
    }
    return [uplevel 1 [list ::__puts_builtin $chan $str]]
}

proc ::gets {chan {varName ""}} {
    if {$chan ne "stdin"} {
        return [uplevel 1 [list ::__gets_builtin $chan $varName]]
    }
    set line [__pygets]
    if {$line eq "\x00__PYSTDIN_EOF__\x00"} {
        if {$varName ne ""} { uplevel 1 [list set $varName ""] }
        return ""
    }
    if {$varName ne ""} {
        uplevel 1 [list set $varName $line]
        return [string length $line]
    }
    return $line
}

# ============ 2. exit：记录退出码，再抛出一个可识别的错误 ============
# 裸 Tcl 解释器没有 exit 命令；这里补上，并让 __tclsh_main 读出退出码。
if {[llength [info commands exit]]} { rename ::exit ::__exit_builtin }
proc ::exit {{code 0}} {
    set ::__exit_code $code
    return -code error -errorcode [list PYEXIT $code] "PYEXIT [string cat $code]"
}

# ============ 3. exec：用 Python 子进程实现，管道与退出码更可靠 ============
# 支持 tclsh 风格的 "> file"、"2> file"、">& file" 重定向（不做完整管道语法）。
# 注意：Tcl 的 exec 会把命令和参数作为「多个参数」传进来，桥接到 Python 前
# 必须先用 list 合成一个字符串，否则 Python 侧会把字符串拆成单个字符。
if {[llength [info commands exec]]} { rename ::exec ::__exec_builtin }
proc ::__pyexec_args {args} {
    return [__pyexec [list {*}$args]]
}
proc ::exec {args} {
    if {[llength $args] == 0} { return -code error "exec: 参数为空" }

    set cmd {}
    set outfile ""
    set errfile ""
    set i 0
    while {$i < [llength $args]} {
        set a [lindex $args $i]
        switch -- $a {
            ">"  { incr i ; set outfile [lindex $args $i] ; set errfile $outfile }
            ">>" { incr i ; set outfile [lindex $args $i] ; set errfile $outfile }
            "2>" { incr i ; set errfile [lindex $args $i] }
            "2>>" { incr i ; set errfile [lindex $args $i] }
            ">&" { incr i ; set outfile [lindex $args $i] ; set errfile $outfile }
            default { lappend cmd $a }
        }
        incr i
    }
    if {[llength $cmd] == 0} { return -code error "exec: 缺少要执行的命令" }

    set rc [__pyexec [list {*}$cmd]]
    lassign $rc code out err

    if {$outfile ne ""} {
        set fh [open $outfile w]
        fconfigure $fh -encoding utf-8 -translation lf
        puts -nonewline $fh $out
        close $fh
    }
    if {$errfile ne "" && $errfile ne $outfile} {
        set fh [open $errfile w]
        fconfigure $fh -encoding utf-8 -translation lf
        puts -nonewline $fh $err
        close $fh
    }
    if {$errfile eq "" && $outfile eq "" && $err ne ""} {
        set out "${out}${err}"
    }

    if {$code != 0} {
        return -code error -errorcode [list CHILDSTATUS 0 $code] [string trim $out]
    }
    return $out
}

# ============ 4. 修正 auto_load 对 tclIndex 的处理 ============
# 现象：裸 Tcl 解释器（tkinter 内嵌）遇到 `#!/usr/bin/env tclsh` 这种 shebang 时，
# 会把 tclsh 当成命令去找，触发 auto_load，然后报
#   "…/tcl8.6/tclIndex isn't a proper Tcl index file"
# 这是一个与脚本本身无关的误导性报错。解决办法：把 tclIndex 读进全局命名空间，
# 让 auto_index 正确建立；同时保证找不到任何文件时也不要用误导性的错误中断。
if {[catch {info nameofexecutable} _]} { set _ "" }
set ::__tcl_dir [file join [file dirname [info library]]]
rename ::auto_load ::__auto_load_orig
proc ::auto_load {cmd {namespace {}}} {
    set found ""
    foreach dir [list $::__tcl_dir [info library]] {
        set f [file join $dir tclIndex]
        if {[file exists $f]} { set found $f ; break }
    }
    if {$found ne ""} {
        # 用 source -encoding utf-8 读入，避免 Tcl 9 的 index 2.0 格式解析失败
        set fh [open $found r]
        fconfigure $fh -encoding utf-8
        set data [read $fh]
        close $fh
        set rc [catch {uplevel #0 $data} msg]
        if {$rc} { return $cmd }
        if {[info exists ::auto_index($cmd)]} {
            set script $::auto_index($cmd)
            if {[llength $script] > 1} {
                set script [lreplace $script end end $namespace]
            }
            return [uplevel #0 $script]
        }
    }
    return $cmd
}

# ============ 5. 若 Tcl 低于 8.5，补一个最小 dict ============
if {[catch {dict size {}} _]} {
    proc ::dict {sub cmd args} {
        switch -- $sub {
            create  { return {} }
            set     { return [lset cmd $args] }
            get     { return [lindex $cmd $args] }
            exists  { return [expr {$args ne "" && $args < [llength $cmd]}] }
            keys    { set k {} ; foreach {a b} $cmd { lappend k $a } ; return $k }
            values  { set v {} ; foreach {a b} $cmd { lappend v $b } ; return $v }
            size    { return [expr {[llength $cmd] / 2}] }
            default {
                if {[llength $args] > 0} { return [dict get $cmd $args] }
                return {}
            }
        }
    }
}

# ============ 6. 按 tclsh 的规则执行脚本 ============
# 注意：这里不用 catch 包住脚本，退出码放在全局变量 __exit_code 里，
# 由 Python 侧区分「脚本主动 exit」和「脚本报错」。
proc ::__tclsh_main {} {
    global argv argv0 argc tcl_interactive
    if {$argc > 0} {
        set script [file normalize [lindex $argv 0]]
        set argv   [lrange $argv 1 end]
        set argc   [expr {$argc - 1}]
        set argv0  $script
        set tcl_interactive 0
        if {![file exists $script]} {
            puts stderr "couldn't read file \"$script\": no such file or directory"
            set ::__exit_code 1
            return 1
        }
        uplevel #0 [list source $script]
        return 0
    } else {
        set tcl_interactive 1
        set argv0 "tclsh"
        return 0
    }
}
'''

HELP = """用法:
  python tclsh.py                          交互模式
  python tclsh.py <script.tcl> [args...]   运行脚本
"""


def _tcl_list_to_argv(text: str):
    """把 Tcl 规范化的 list 字符串拆回参数表（支持 {} 与 "" 引用）。

    例：'{python} {-c} {print(1)}'          -> ['python', '-c', 'print(1)']
        'C:/Program Files/py.exe -V'        -> ['C:/Program Files/py.exe', '-V']
    """
    out, i, n = [], 0, len(text)
    while i < n:
        while i < n and text[i] in " \t\r\n":
            i += 1
        if i >= n:
            break
        if text[i] == "{":
            depth, i, buf = 1, i + 1, []
            while i < n and depth:
                if text[i] == "\\" and i + 1 < n:
                    buf.append(text[i + 1])
                    i += 2
                    continue
                if text[i] == "{":
                    depth += 1
                elif text[i] == "}":
                    depth -= 1
                    if depth == 0:
                        i += 1
                        break
                buf.append(text[i])
                i += 1
            out.append("".join(buf))
        elif text[i] == '"':
            i += 1
            buf = []
            while i < n and text[i] != '"':
                if text[i] == "\\" and i + 1 < n:
                    i += 1
                buf.append(text[i])
                i += 1
            i += 1
            out.append("".join(buf))
        else:
            buf = []
            while i < n and text[i] not in " \t\r\n":
                if text[i] == "\\" and i + 1 < n:
                    i += 1
                buf.append(text[i])
                i += 1
            out.append("".join(buf))
    return out


def _configure_output() -> None:
    """让 puts 出去的中文在「控制台」和「管道/重定向」下都不炸、不乱码。

    - 控制台（tty）：保留系统编码（中文 Windows 用 cp936），Python 走
      WriteConsoleW，中文直接显示正常；
    - 管道/重定向：强制 UTF-8 并容错替换，脚本里写中文注释/输出不会抛
      UnicodeEncodeError，重定向到文件后也是标准 UTF-8。
    """
    for stream in (sys.stdout, sys.stderr):
        try:
            if stream.isatty():
                continue
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass


def main() -> int:
    _configure_output()
    try:
        import tkinter
    except Exception as exc:  # pragma: no cover
        sys.stderr.write(
            "无法创建内嵌 Tcl 解释器：%s\n"
            "请确认 Python 安装时包含 tcl/tk（Windows 官方安装包默认包含）。\n" % exc
        )
        return 1

    if len(sys.argv) > 1 and sys.argv[1] in ("-h", "--help", "/?"):
        print(HELP, end="")
        return 0

    interp = tkinter.Tcl()
    interp.setvar("__pypath", sys.executable)

    def py_puts(chan, text, nonewline):
        stream = sys.stderr if str(chan) == "stderr" else sys.stdout
        stream.write(str(text))
        if int(nonewline) == 0:
            stream.write("\n")
        stream.flush()
        return ""

    def py_gets():
        try:
            return input()
        except EOFError:
            return EOF_SENTINEL

    def py_exec(cmdlist):
        # Tcl 侧只传一个参数（Tcl list 字符串），所以这里 cmdlist 通常是 str；
        # 如果被当成可迭代对象逐个字符处理，"python -V" 会被拆成单字符。
        if isinstance(cmdlist, (list, tuple)):
            cmdstr = " ".join(str(x) for x in cmdlist)
        else:
            cmdstr = str(cmdlist)
        try:
            argv = _tcl_list_to_argv(cmdstr)
        except Exception as exc:
            return [126, "", "无法解析命令: %s (%s)" % (cmdstr, exc)]
        if not argv:
            return [126, "", "exec: 缺少要执行的命令"]
        try:
            proc = subprocess.run(argv, capture_output=True, shell=False)
        except FileNotFoundError as exc:
            return [127, "", str(exc)]
        except OSError as exc:
            return [126, "", str(exc)]
        out = proc.stdout.decode("utf-8", "replace").replace("\r\n", "\n")
        err = proc.stderr.decode("utf-8", "replace").replace("\r\n", "\n")
        return [proc.returncode, out, err]

    interp.createcommand("__pyputs", py_puts)
    interp.createcommand("__pygets", py_gets)
    interp.createcommand("__pyexec", py_exec)

    try:
        interp.eval(BOOTSTRAP)
    except Exception as exc:
        sys.stderr.write("Tcl 引导失败：%s\n" % exc)
        return 1

    interp.setvar("argv0", sys.argv[0] if len(sys.argv) > 1 else "tclsh")
    interp.setvar("argv", sys.argv[1:])
    interp.setvar("argc", len(sys.argv) - 1)
    interp.setvar("tcl_interactive", 0)
    interp.setvar("__exit_code", "")

    # ---------------- 交互模式 ----------------
    if len(sys.argv) == 1:
        interp.eval("set argv0 tclsh; set argv {}; set argc 0; set tcl_interactive 1")
        print("Tcl %s / Python-hosted（Windows 无 tclsh 时的替代）"
              % interp.eval("info patchlevel"))
        print("输入表达式回车即执行；exit 退出。")
        while True:
            try:
                line = input("% ")
            except (EOFError, KeyboardInterrupt):
                print()
                return 0
            if not line.strip():
                continue
            try:
                result = interp.eval(line)
                if str(result) != "":
                    print(result)
            except Exception as exc:
                msg = str(exc)
                if "PYEXIT" in msg:
                    return int(interp.eval("set ::__exit_code"))
                print(msg, file=sys.stderr)

    # ---------------- 脚本模式 ----------------
    try:
        interp.eval("::__tclsh_main")
    except Exception as exc:
        msg = str(exc)
        code = _exit_code(interp)
        if os.environ.get("TCLSH_DEBUG"):
            sys.stderr.write("DEBUG msg=<%s> code=<%s>\n" % (msg.strip(), code))
        if code is not None:
            return code
        sys.stderr.write(msg.strip() + "\n")
        return 1

    code = _exit_code(interp)
    return code if code is not None else 0


def _exit_code(interp):
    """读取 Tcl 侧记录的退出码；脚本报错（未 exit）时返回 None。"""
    try:
        raw = str(interp.eval("set ::__exit_code"))
    except Exception:
        return None
    if raw == "":
        return None
    try:
        return int(raw)
    except ValueError:
        return None


if __name__ == "__main__":
    sys.exit(main())

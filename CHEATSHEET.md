# Tcl 速查表（我自己踩过的坑 + 常用模板）

> 每次收工把新踩的坑加进来。这份文件比 AI 对话历史有用一百倍——
> 查一次 5 秒，而且永远不会「上下文太多」。

跑法（在 `tcl-practice` 目录下）：
```powershell
python ..\tools\tclsh.py basics\01_basics.tcl
```

---

## 一、我反复犯的错（按出现频率排序）

### 1. 忘保存 ⭐⭐⭐⭐⭐

**现象**：报错和我屏幕上的代码对不上；「改了但输出没变」。
**根因**：Tcl 读的是**磁盘上的文件**，不是编辑器缓冲区。
**检查**：标签页文件名旁的 `●` 圆点消失 = 已保存。
**动作**：改完立刻 `Ctrl+S`，然后立刻跑一次。

### 2. 命令替换漏 `[]` ⭐⭐⭐⭐⭐

```tcl
puts "长度: [llength $list]"      ✅
puts "长度: (llength $list)"      ❌ 圆括号无效
puts "长度: llength $list"        ❌ 命令不执行，原样输出文字
[ $dir $base $ext ]               ❌ 把 $dir 当命令名执行
[list $dir $base $ext]            ✅ list 才是命令名
```
**记牢**：方括号里的**第一个词永远是命令名**。

### 3. 命令名和参数之间缺空格 ⭐⭐⭐⭐⭐

```tcl
if{$x > 1} { }        ❌ → if {...} {
expr{7-1}             ❌ → expr {7-1}
} else{  }            ❌ → } else {
```
**Tcl 是空格分隔的语言**，和 C/Python 相反（那边 `if(` 可以紧贴）。
今天的证据：`if{` → `extra characters after close-brace`；`expr{7-1}` → `bad index "expr{7-1}"`。

### 4. 表达式里漏 `$` ⭐⭐⭐⭐

```tcl
expr {$a / $b}        ✅
expr {a / b}          ❌ invalid bareword "a" ... should be "$a"
if {$b == 0} { }      ✅
if {b != 0} { }       ❌ 同上
```

### 5. 整数除法 ⭐⭐⭐⭐

```tcl
expr {5 / 9}          → 0        两个整数相除，小数被丢弃
expr {5.0 / 9.0}      → 0.5555   任一边是浮点就按浮点算
expr {5 * 1.0 / 9}    → 0.5555   「乘 1.0」是最省事的转浮点写法
```
**测试数据要含边角值**：`f2c` 用 98.6/32/212 碰巧都对，换成 100 才暴露 bug。

### 6. 正则里 `\s` 应为 `\s+` ⭐⭐⭐⭐

```tcl
{(\S+)\s(\S+)}        ❌ 只吃一个空格，遇到多个空格就错位
{(\S+)\s+(\S+)}       ✅ 一个或多个空格
```
证据：`split` 一行日志拆出 13 个字段（7 个是空串），因为字段间有 8 个空格。

### 7. 返回多个值时用字符串拼接 ⭐⭐⭐

```tcl
return [list $a $b]           ✅ 结构有保证，值含空格也不怕
return "$a $b"                ❌ 值里有空格 → llength 变多，静默出错
return "{$a $b}"              ⚠️ 显示像 list，但 llength=1（是个字符串）
```
**函数返回数据，调用处决定怎么显示。**

### 8. 变量名用纯数字 ⭐⭐

```tcl
set 0 { }             可运行，但读起来像数字字面量
set nums { }          ✅ 用有意义的英文名
```

### 9. 在 proc 体内用「注释掉」废弃代码 ⭐⭐⭐

`#` **只在命令开始的位置**才算注释。写在 `proc` 花括号里、或一行中间，`#` 只是普通字符，花括号照样计数。

```tcl
proc f {} {
#    if {[regexp ...]} {        ← 花括号没配对！
    if {[regexp ...]} { }      ← 报 missing close-brace
}
```
**动作**：废弃代码直接删行（VS Code 里 `Ctrl+Shift+K`），别注释留着。

### 10. 正则里 `{}` 是元字符，不是「保护符」 ⭐⭐⭐

```tcl
set re {(\S+)\s+(\d+)}        ✅ 外层花括号负责"不替换"，里面用【圆括号】分组
set re {{\S+}\s+{\d+}}        ❌ 花括号在正则里表示"重复次数"，这行要求日志里真有 { }
```
**证据**：闭卷重写 log_summary 时把 `(\S+)` 写成 `{\S+}`，`test_run.log` 25 行数据
**一行都不匹配**，三个计数器全 0，**不报任何错**。
**预防**：正则改完，先用**一行真数据**单独 `regexp` 验一次，再放进循环。

### 11. `if {![regexp ...]}` 把逻辑写反 ⭐⭐⭐

```tcl
if {[regexp $re $line -> ...]} { ... }     ✅ 匹配【成功】才处理
if {![regexp $re $line -> ...]} { ... }    ❌ 这是匹配【失败】才进分支
```
**证据**：报错 `can't read "status": no such variable`。
因为 `regexp` 匹配失败时**根本不给变量赋值**（不是设成空串，是保持原样或不存在）。
**记牢**：`regexp` 返回 1 才赋值；返回 0 时所有捕获变量动都不动。

### 12. `exit` 写进循环 → 输出全丢 ⭐⭐⭐

**证据**：`exit 2` 放在 `while` 里，读到第一条 FAIL 就终止进程，屏幕只剩 `exit=2`，
后面 9 行 `puts` 一次都没执行；`PATHS`/`PASS` 全是 0。
**规矩**：**先把所有结果打印完，最后才决定退出码。**
`exit` 不是「记下返回码」，是当场杀死脚本，`catch` 也拦不住它。

### 13. 复制 if 块忘改命令名 ⭐⭐

```tcl
if {![file exists $path]} { ... }        ;# 检查「不存在」
if {[file exists $path] == 0} { ... }    ❌ 复制后没改，还是检查「不存在」
if {[file size $path] == 0} { ... }      ✅ 检查「空文件」
```
**证据**：空文件检查永久失效，空文件退出码 0，提示文字却写着「存在但为空」。
**预防**：复制条件块后逐字核对**命令名**，不只核对变量名。

### 14. `incr` 的参数是变量名，不带 `$` ⭐⭐

```tcl
incr PATHS          ✅ 把 PATHS 加 1
incr $PATHS         ❌ 把「名字叫 0 的变量」加 1（因为 $PATHS 当前值是 0）
```
**证据**：`puts "PATHS: [incr $PATHS]"` 打印出 1，而 `PATHS` 本身还是 0；
`info exists 0` → 1（真创建了个叫 `0` 的变量）。
另外：**打印不要用 `incr`**，它每调用一次就自增一次，等于每打印一次多算一条。

### 15. `gets` 第三个参数是变量名，`close` 要通道名 ⭐

```tcl
gets $fh line       ✅ 把读到的行放进 line
gets $fh $line      ❌ 拿 $line 的值当变量名
close $fh           ✅
close $path         ❌ can not find channel named "fixtures/timing_normal.rpt"
```
`[open ...]` 返回的是**通道名**（类似 `file3`），不是文件名。

### 16. 契约字段名的大小写也是契约 ⭐⭐

**证据**：输出写成 `WORST_Path:`，测试正则 `{WORST_PATH:...}` **区分大小写**，断言直接红；
而 PowerShell 的 `-match` **默认不区分大小写**，会把这种情况判成「看起来对」——差点骗过自己。
**预防**：字段名从契约里**复制粘贴**，不要凭记忆敲；验证用 Tcl 的 `regexp`（敏感）而不是肉眼看，
需要不敏感时才加 `-nocase`。

### 17. 一句 `puts` 里引号只能有一对 ⭐

```tcl
puts "WORST_path: "$worst_start -> $end"    ❌ extra characters after close-quote
puts "WORST_PATH: $worst_start -> $end"     ✅
```
**症状**：前面的 `puts` 都正常打印了，走到这一行突然报语法错——
因为 Tcl **逐条执行**，语法错误只在那一条被执行时才触发。
**动作**：长 `puts` 写完后数一遍引号，必须是偶数且两两配对。

### 18. 命令名写错 → 报错却说「expected boolean value」 ⭐⭐⭐

**证据**（10/26）：把设计草图 `parse_report(path) -> dict {...} {` 当代码贴进 `report_summary.tcl:28`，
报错是 `expected boolean value but got "parse_report(path)"`，**和真实原因毫无关系**。

**根因**：那整行被当成**一条命令的名字**；命令不存在时，这个解释器的 `unknown` 过程
内部拿命令名去 `if {$msg}`，于是报“需要布尔值”。

**诊断**：别读报错文字，用 `catch` 看错误栈：

```tcl
set rc [catch {危险代码} msg opts]
puts [dict get $opts -errorinfo]     ;# 找 "invoked from within" 那一行，它就是元凶原样
```

**预防**：设计草图放注释里（`#` 必须在行首），别直接粘进代码。

### 19. `[]` 里的换行是命令分隔符，不是续行 ⭐⭐⭐

```tcl
return [dict create a 1 b 2
             c 3]                    ❌ 第二行变成新命令 c，报 "boolean"/"invalid command name"
return [dict create a 1 b 2 c 3]     ✅ 一行写完（推荐）
return [dict create a 1 \
             b 2]                    ✅ \ 续行，但 \ 后面不能有空格
```

**证据**（10/27）：`return [dict create ... violations $VIOLATIONS` 换行写 `worst_start ...]`，
报 `expected boolean value but got "worst_start"`。和 #18 同一个机制。

**预防**：命令替换里**一律一行写完**；必须换行时用 `\`，且写完检查 `\` 后没有空格。

### 20. 粘贴位置：`set` 落进了不该进的 proc ⭐⭐

**证据**（10/27）：`can't read "rep": no such variable`，但文件里明明有 `set rep ...`——
它被粘进了 `proc usage {}`（只有参数个数不对时才执行），主流程永远读不到。

**根因**：粘贴前光标停在那个 proc 里，`set` 变成了它的局部变量。

**预防**：粘贴前确认光标在**顶层**（行首无缩进、不在任何 `{}` 内）；粘完搜一次变量名看它落在第几行。

### 21. `dict get` 用错 dict → `key "xxx" not known in dictionary` ⭐⭐⭐

**证据**（10/27）：拆 proc 后先报 `key "wns"`（用了 `$rep` 去取 `$summary` 的键），
改完又报 `key "invalid"`（反过来把 `$rep` 的键写成 `$summary`）。

**记牢**：`dict get` 缺键是**报错**，不是返回空串。两个 dict 各有各的键：

| dict | 谁产 | 键 |
|---|---|---|
| `report` | `parse_report` | `design` `corner` `records` `invalid` |
| `summary` | `compute_summary` | `wns` `tns` `violations` `worst_start` `worst_end` `paths` |

**预防**：拆完 proc 立刻把这张表写进 `parser-design.md`，取值前对表。

---

## 二、核心语法速查

### 替换规则（最重要）

| 写法 | 行为 |
|---|---|
| `"$x [cmd]"` | 变量替换 + 命令替换 |
| `{$x [cmd]}` | **原样**，不替换 |
| `$x` | 变量替换 |
| `[cmd]` | 命令替换（先执行，把结果放这里） |

### 判断

```tcl
if {$x > 1} { ... } elseif {...} { ... } else { ... }
switch -- $op {
    "+" { ... }
    default { ... }        ;# 别省！没写的话未知值静默走空
}
```
**字符串比较用 `eq`/`ne`，数值比较用 `==`/`!=`**：
```tcl
"01" == "1"  → 1    （数值相等）
"01" eq "1"  → 0    （字符串不等）
```

### 循环

```tcl
foreach x $list { ... }
for {set i 1} {$i <= $n} {incr i} { ... }
while {$i <= $n} { ... ; incr i }
```
**累加一律 `lappend`，不要字符串拼接**（实测 2000 元素时 `lappend` 快 2.4 倍，n 越大差距越大）。

### list 家族

```tcl
set l [list a b c]
llength $l          ;# 3
lindex $l 1         ;# b
lrange $l 1 end     ;# b c
lappend l d         ;# 追加（原地改，O(1)）
lsort $l            ;# 排序
lsearch $l b        ;# 返回下标
lreplace $l 0 0     ;# 删掉第 0 个
lassign $l x y z    ;# 一次拆成多个变量
join $l ","         ;# 变字符串
```

### string 家族

```tcl
split "a_b_c" _         ;# → a b c
string length $s
string index $s 0       ;# 单个字符
string range $s 1 end   ;# 子串
string last "/" $path   ;# 最后一个的位置（返回数字，找不到 -1）
string totitle $s       ;# 首字母大写（只作用于【一个字符串】）
string toupper $s
string map {ERROR error} $s
```
**注意**：`string totitle` 处理整个 list 时只管到第一个词 → 要 `foreach` 逐个处理。

### 正则

```tcl
regexp {^(\d{4}-\d{2}-\d{2})\s+(\S+)$} $line -> d rest
if {[regexp $pat $line -> a b c]} {
    # 匹配成功，a b c 已赋值
} else {
    error "格式不对: $line"
}
```
| 符号 | 含义 |
|---|---|
| `\d` `\S` `\s` | 数字 / 非空白 / 空白 |
| `+` `*` `?` | 一个或多个 / 零或多个 / 零或一个 |
| `{4}` `{2,5}` | **元字符**：前面那个单元重复 4 次 / 2~5 次。所以分组只能用 `(...)`，写 `{\S+}` 会要求日志里真有 `{ }` |
| `(...)` | 捕获组（有几个组就写几个变量） |
| `^` `$` | 行首 / 行尾 |
| `\|` | **要匹配竖线字符本身**时转义；想表达「或」则不转义 |

### 错误处理

```tcl
if {[catch {危险命令} result]} {
    return "ERR:$result"      ;# result = 错误信息
}
                            ;# 成功路径：result = 返回值
error "自定义错误信息"          ;# 抛异常
```
`catch` 返回码：`0`=成功 `1`=错误 `2`=return `3`=break `4`=continue
**`catch` 后面必须用 `{}`**（方括号会立刻执行，异常提前抛出）。
拿错误码：`catch {cmd} result opts` → `dict get $opts -errorcode`
（如 `POSIX ENOENT` = 文件不存在、`ARITH DIVZERO` = 除零）

### 作用域

```tcl
set hits 0
proc bump {} {
    set hits 0        ;# 这是【新的局部变量】，和外面无关
    incr hits
}
proc bump2 {varname} {
    upvar 1 $varname h    ;# h 成为调用者那个变量的别名
    incr h
}
```
- proc 里的 `set` 默认建局部变量；**同名 ≠ 同一个变量**
- `upvar 1 名字 别名`：`1` = 上一层（调用者），`#0` = 全局
- `global x` 等价于 `upvar #0 x x`
- ⚠️ **`upvar` 找不到目标不报错，会在调用者那里创建它**——拼错名字会静默产生垃圾全局变量
- **能用「返回 list + lassign」就别用 upvar**（显式、安全）

### 文件 I/O

```tcl
set fh [open $path r]
while {[gets $fh line] >= 0} { ... }
close $fh
read $fh              ;# 一次读全部
file exists $path
file size $path
file tail $path       ;# 取文件名
```
- `[open ...]` 返回的是**通道名**（类似 `file3`），不是文件名 → 必须 `set fh [open ...]`
- `gets $fh line`：第三个参数是**变量名**，不带 `$`
- `close $path` 会报 `can not find channel named "..."`
- 默认 `-translation` 是 `auto`，CRLF 会被自动转成 LF（**实测**：58 字节的行读到 57 字节）

### 命令行参数与退出码

```tcl
if {$argc != 1} { puts stderr "用法: ..." ; exit 1 }
set path [lindex $argv 0]
exit 0        ;# 成功
exit 1        ;# 用法/文件错误
exit 2        ;# 数据有问题
```

---

## 三、常用模板

### 模板 1：带参数检查和错误处理的主流程

```tcl
proc usage {} { puts stderr "用法: tclsh xxx.tcl <文件>" }

if {$argc != 1} { usage ; exit 1 }
set path [lindex $argv 0]
if {![file exists $path]} {
    puts stderr "错误: 找不到文件 \"$path\""
    exit 1
}
if {[file size $path] == 0} {
    puts stderr "错误: 文件是空的"
    exit 1
}
```

### 模板 2：逐行读 + 正则解析 + 统计

```tcl
set re {^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})\s+(\S+)\s+(\S+)\s+(PASS|FAIL)\s+(\d+)$}
set n_pass 0
set n_fail 0
set bad {}
set fh [open $path r]
while {[gets $fh line] >= 0} {
    set line [string trim $line]
    if {$line eq ""} { continue }
    if {![regexp $re $line -> date tm level tcase status ms]} {
        lappend bad $line
        continue
    }
    switch -- $status {
        PASS { incr n_pass }
        FAIL { incr n_fail }
    }
}
close $fh
```

### 模板 3：过程返回多值

```tcl
proc parse {path} {
    ...
    return [list $design $corner $wns $tns]
}
lassign [parse $f] design corner wns tns
```

---

## 四、调试技巧

1. **报错和代码对不上** → 先查保存（`Ctrl+S`）、再查跑的是不是这个文件
2. **Tcl 报错行号常常偏后/偏移** → 从文件末尾往前删代码，第一次不报错的地方，问题就在它后面
3. **怀疑某段语法** → 抄进独立小文件单独跑，排除文件里其他部分的影响
4. **结果「看起来对」** → 一定加边角测试（0、负数、空、超大、格式错误）
5. **`puts` 定位** → 在关键步骤打印变量，确认走到哪一步

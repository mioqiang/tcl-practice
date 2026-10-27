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

### 22. Tcl 的三种「静默失败」：漏 `$` / 结果没人接 / 越界取值 ⭐⭐⭐⭐

一晚踩了三个，症状不同、根因同一个：**Tcl 从不提醒你"这个值没人用"、"这个变量是空的"**。

| 写法 | 你以为 | 实际 | 症状 |
|---|---|---|---|
| `return [list path rep summmary]` | 返回三个变量的值 | 返回三个**字符串** `path` `rep` `summmary` | `puts` 打出变量名本身，**不报错** |
| `join $header ,` 单独一行 | 写表头 | 算出字符串然后扔掉 | 表头缺失，**不报错** |
| `set path [lindex $argv 1]`（只有 1 个参数） | 取第 2 个参数 | 越界 → **空串** | `Error:路径 "" 不存在`，退出码 1 |

**证据**（10/27）：屏幕上真的打出过 `DEBUG :path rep summmary`——连 `summmary` 三个 m 都是调用处传进来的字面量；
CSV 修好 `open` 后只有数据没有表头；`lindex $argv 1` 让 19 条断言红了 12 条。

**记牢**：

- **漏 `$` 比拼错名字更危险**：`$summmary` 会报 `can't read "summmary"`，`summmary` 什么都不报。
- 每个 `set` 都应该在后面的 `return`/`puts` 里被用到 —— 写完 `return` 往回数一遍变量。
- 命令的结果必须有去处：`set` / `puts` / `return` / 当参数。**单独一行 = 白算**。
- `lindex` / `lassign` / `dict get` 缺东西时，**只有 `dict get` 会报错**，另两个安静地给空串。

**判据**：报错里出现 `""`（空引号），或屏幕上打出变量名本身 → 先问两句：**这个值从哪个下标/键来的？它最后去哪了？**

### 23. 伪代码 / 骨架缩写直接留在代码里 ⭐⭐

**证据**（10/27）：写 `write_csv` 时把骨架里的

```tcl
open .... w
```

原样留下（`....` 是"这里该填变量"的占位）。报错是 `couldn't open "....": permission denied`——
Tcl 把 `....` 当成了**文件名**；而且 `open` 的返回值没接住，通道名也一并丢了。

**根因**：草稿里的缩写不是代码，`...`、`<占位>`、`TODO` 都会变成真实的命令参数。

**预防**：写完搜一遍 `...` / `TODO` / `<`；`open` 一律写 `set fh [open $path w]`（**返回值必须接住**）。

### 24. `exit 1` 是双义码：未捕获的 Tcl 错误也落在 1 ⭐⭐⭐

**证据**（10/27，两次）：Gate 1 的 `key "path" not known` 让本该 `exit 2` 的 malformed 报了 **1**；
Gate 2 的 `couldn't open` 让屏幕 9 行全对、退出码却是 **1**。两次都先怀疑"数据有问题"，其实是**代码抛错**。

**根因**：契约里 `1` = 用法/文件错误、`2` = 数据有问题；但任何没被 `catch` 住的 Tcl 错误，退出码都是 **1**。

**记牢**：**屏幕输出正常但 `exit=1`** → 错误在最后一个 `puts` 之后、`exit` 之前，先看 stderr 的原话。
（想彻底分开的话，可以在主流程外包一层 `catch`，用 `exit 3` 表示"解析器内部错误"；现在不做，记进 `parser-design.md` 已知限制。）

---

## 二、核心语法速查（按「你想干什么」分组）

> 分组顺序 = 写一个解析器的自然顺序：地基 → 结构 → 数据 → 正则 → 控制流 → I/O → 命令行 → 调试。
> 带 `:行号` 的例子取自 `report_summary.tcl`（行号会随改动漂移，只当定位线索）。
> 语法错误对照看第一节的 1-24 条。

### 0. 地基：替换规则（其他全部建立在这上面）

| 写法 | 行为 | 什么时候用 |
|---|---|---|
| `$x` | 变量替换 | 取变量的值 |
| `[cmd]` | 命令替换：先执行，把结果放这里 | 需要"算"一个值 |
| `"$x [cmd]"` | 两者都替换 | 拼给人看的字符串 |
| `{...}` | **原样**，什么都不替换 | 正则、`expr` 条件、`if` 条件、proc 体 |

**一句话**：想让 Tcl "算"，就用 `[]` 或 `$`；想让它"原样保留"，就用 `{}`。
**记牢**：方括号里的**第一个词永远是命令名**（写 `( expr {...} )` 无效，见错 #2）。

### 1. 结构与作用域 —— 让一段逻辑有名字

| 语法 | 作用 | 例子 / 坑 |
|---|---|---|
| `proc name {参数} { 函数体 }` | 定义一条新命令 | `parse_report :27` / `compute_summary :60` |
| `return $值` | 把值交回调用者 | 只能返回**一个**值 → 多值用 `list` 或 `dict`（错 #7） |
| `set v 值` | 赋值 | proc 里默认是**局部变量** |
| `\` 放行尾 | 一条命令拆多行 | `:78-80`；`\` 后**不能有空格**（错 #19） |

**作用域**（拆 proc 之后最要紧的一节）：

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
- `upvar 1 名字 别名`：`1` = 上一层（调用者），`#0` = 全局；`global x` 等价 `upvar #0 x x`
- ⚠️ `upvar` 找不到目标**不报错**，会在调用者那里创建它 → 拼错名字会静默产生垃圾全局变量
- **能用「返回 list + `lassign`」就别用 `upvar`**（显式、安全）

**拆 proc 的代价**：调用方必须记住"谁产什么键"。这就是下面第 2 节两张键表存在的理由。

### 2. dict —— 让「返回 4~6 个值」有名字

| 语法 | 作用 | 例子 / 坑 |
|---|---|---|
| `dict create k1 v1 k2 v2` | 造字典 | `:58` `:78`；键值必须成对 |
| `dict get $d $key` | 取值 | **缺键 = 报错**，不是空串（错 #21） |
| `dict keys $d` | 列出全部键 | 动手前查一次，一秒看清键表 |
| `dict exists $d $k` | 先探再取 | 不确定时用它兜住 |

**两张键表就是数据契约**：

| dict | 谁产 | 键 | 谁消费 |
|---|---|---|---|
| `report` | `parse_report` | `design` `corner` `records` `invalid` | `format_row`、main 的退出码 |
| `summary` | `compute_summary` | `wns` `tns` `violations` `worst_start` `worst_end` `paths` | `format_row`、main 的 9 行输出 |

**为什么用 dict 而不 `return "$a $b $c"`**：字符串只能靠**位置**记，写错顺序不报错、结果全歪；dict 靠**名字**取，取错立刻报 `key ... not known`。代价是要维护这张表。

### 3. list —— 一条路径 = 一个三元组

| 语法 | 作用 | 例子 / 坑 |
|---|---|---|
| `list a b c` | 造列表（元素是**值**） | `:44` `:92`；漏 `$` 就存字面量，**且不报错** |
| `lappend var $x` | 追加（原地、O(1)） | `:44`；累加一律用它，别字符串拼接（实测 2000 元素快 2.4 倍） |
| `llength $l` | 元素个数 | `:80` 的 `paths` 靠它做到"同源" |
| `lindex $l i` | 取第 i 个 | 越界返回**空串**，不报错 |
| `lrange $l 1 end` | 切片 | |
| `lassign $rec a b c` | 一次拆成多个变量 | `:67`；元素不够 → 后面变量是空串，**不报错** |
| `join $l ,` | 拼成字符串（**只算，不写**） | `:99` `:101`；结果没人接 = 白算 |
| `foreach x $l { }` | 遍历 | `:66` `:100` |
| `lsort $l` | 默认按字符串排序 | 按数值排要 `-integer`/`-real` 或 `-command` |
| `lsearch $l b` | 返回下标（找不到 -1） | |
| `lreplace $l 0 0` | 删掉第 0 个 | |

**嵌套 list 是本项目的核心数据结构**：

```text
records = { {start1 end1 -0.483}  {start2 end2 0.120}  ... }
             └── 每条记录是一个三元组 list ──┘
```

于是"路径总数" = `llength records`，"第 i 条的 slack" = `lindex [lindex $records $i] 2`。
**用结构代替并行的多个数组**，两者就不可能漂移（`paths` 同源就是这条）。

### 4. string / format / file —— 把文本变成字段

| 语法 | 作用 | 例子 / 坑 |
|---|---|---|
| `string trim $s` | 去首尾空白 | `:36`；不去 `\r` 会让 `$` 锚点失配 |
| `string length/index/range/last` | 长度/单字符/子串/最后位置 | `string last "/" $path` 找不到返回 -1 |
| `string map {a b} $s` | 批量替换 | 顺序敏感 |
| `string match {*[,\"]*} $s` | glob 通配符匹配 | `[]` 在 glob 里是字符集，**不是命令替换** |
| `string is double -strict $v` | "是不是合法数字" | `:43`；不用 `-strict` 时空串也算数字 |
| `string totitle $s` | 首字母大写 | **只作用于一个串**，处理 list 要 `foreach` |
| `string toupper` / `string compare` | 大写 / 比较 | |
| `format %.3f $v` | 固定 3 位小数 | `:86-87` `:111-112` `:114` |
| `file tail $path` | 取文件名 | `:91`；CSV 的 `file` 列 |
| `file dirname $path` | 取目录 | `:96`；`summary.csv` 返回 `.` |
| `file join $a $b` | 拼路径 | 别手写 `/` 或 `\` |
| `file exists` / `file size` | 存在 / 字节数 | `:17` `:21`；复制 `if` 块忘改命令名（错 #13） |
| `file mkdir $dir` | 建目录 | `:96`；幂等，多级也建 |

**`format` 为什么必须用**：`puts` 直接打浮点会得到 `-0.48`、`0.0` 这种，和契约的 3 位小数不符。
**整数除法**：`expr {5 / 9}` → `0`；`expr {5.0 / 9.0}` → `0.5555`（错 #5）。
**精度要统一**：`format %.3f` 现在在屏幕和 CSV 里各写一遍，改小数位要改 5 处（已知欠账）。

### 5. 正则 —— 把一行拆成字段

| 语法 | 作用 | 例子 / 坑 |
|---|---|---|
| `regexp {pat} $s -> v` | 匹配；捕获组依次赋给变量 | `:37` `:40` `:42` `:51` `:52` |
| 返回值 `1` / `0` | 1 = 成功（变量已赋值）<br>0 = 失败（**变量保持原样**） | 用 `![regexp]` 是把逻辑写反（错 #11） |
| `^` `$` | 行首 / 行尾 | 不写 `^` 会误匹配注释里的 `Startpoint:` |
| `\s+` | **一个或多个**空白 | 写 `\s` 只吃一个空格，多空格就错位（错 #6） |
| `(\S+)` | 捕获组：非空白串 | 花括号是元字符，写 `{\S+}` 就要求文本里真有 `{}`（错 #7） |
| `(?:MET\|VIOLATED)` | **非捕获**分组 + 或 | `:42`；用 `(...)` 会多一个捕获变量 |
| `\|` | 匹配**字面竖线** | 想表达"或"时不转义 |
| `-nocase` | 忽略大小写 | 默认区分大小写 |

**四条铁律**：

1. 正则**一律用 `{}` 包**（双引号会把 `\d` 吃成 `d`，错 #6）
2. 空白一律 `\s+`，不要 `\s`
3. 分组只用 `(...)` / `(?:...)`，**不要** `{...}`
4. **改完先用一行真数据单独 `regexp` 验一次**，再放进循环——错 #7 那次是 25 行一行都没匹配，还不报错

### 6. 控制流与数值

```tcl
if {$x > 1} { ... } elseif {...} { ... } else { ... }
switch -- $op {
    "+" { ... }
    default { ... }        ;# 别省！没写的话未知值静默走空（bug 记录 10.15）
}
foreach x $list { ... }
for {set i 1} {$i <= $n} {incr i} { ... }
while {$i <= $n} { ... ; incr i }
```

| 语法 | 作用 | 坑 |
|---|---|---|
| `if {cond} { }` | 分支 | `if{` / `}else{` 缺空格（错 #3）；`{}` 里**自动**按表达式求值，别写 `if [expr ...]` |
| `expr { }` | 算术/比较 | 漏 `$` 报 `invalid bareword`（错 #4） |
| `incr v` | 自增 | 参数是**变量名不带 `$`**（错 #14）；打印别用 `incr`（每打一次多算一条） |
| `==` `<` `>` | **数值**比较 | `"01" == "1"` → 1 |
| `eq` `ne` | **字符串**比较 | `"01" eq "1"` → 0 |
| `\|\|` `&&` `!` | 逻辑 | 要写在 `{}` 里 |
| `while {[gets $fh line] >= 0}` | 逐行读到 EOF | `gets` 到 EOF 返回 **-1**，所以是 `>= 0` |

### 7. 文件 I/O

| 语法 | 作用 | 例子 / 坑 |
|---|---|---|
| `set fh [open $path r]` | 打开**读**，返回通道名 | `:29`；返回值必须接住 |
| `set fh [open $out w]` | 打开**写**（截断） | `:97`；`a` = 追加（连跑两次会重复行） |
| `gets $fh line` | 读一行到 `line` | 第三个参数是**变量名**，不写 `$`（错 #15） |
| `puts $x` | 打 stdout | `:108-116`；测试靠它解析字段 |
| `puts stderr $x` | 打 stderr | `:8` `:18` `:22`；用法/错误走这里，不污染 stdout 契约 |
| `puts $fh $x` | 写文件 | `:99` `:101`；**list 会被写成带花括号的形式** → 先 `join` |
| `close $fh` | 关闭并 flush | `:57` `:103`；`exit` 在它之前 = 数据丢失（错 #8） |

- `[open ...]` 返回的是**通道名**（类似 `file3`），不是文件名
- `close $path` 会报 `can not find channel named "..."`
- 默认 `-translation auto`，CRLF 自动转 LF（实测 58 字节的行读到 57 字节）

### 8. 命令行与退出码

| 语法 | 作用 | 坑 |
|---|---|---|
| `$argc` | 参数个数 | 无参数时是 0，不报错 |
| `$argv` | 参数列表 | |
| `lindex $argv 0` | 第 1 个参数 | 越界返回**空串**，不报错 |
| `exit N` | 立即终止 | **不是"记下退出码"**，是当场杀进程（错 #8） |

| 码 | 含义 |
|---|---|
| `0` | 成功 |
| `1` | 用法 / 文件不存在 / 空文件 **（也是未捕获 Tcl 错误的默认码）** |
| `2` | 数据有问题（FAIL 或无效路径） |

⚠️ **未捕获错误的退出码也是 1**，和"用法错误"撞码 → 看到 `exit=1` 但屏幕输出正常，说明错误在 `exit` 之前那段代码里，**先看 stderr**。

### 9. 调试与错误处理

```tcl
if {[catch {危险命令} result]} {
    return "ERR:$result"      ;# result = 错误信息
}
                            ;# 成功路径：result = 返回值
error "自定义错误信息"          ;# 抛异常
```

- `catch` 返回码：`0`=成功 `1`=错误 `2`=return `3`=break `4`=continue
- **`catch` 后面必须用 `{}`**（方括号会立刻执行，异常提前抛出）
- `catch {cmd} result opts` → `dict get $opts -errorinfo` 找 `invoked from within`，那是元凶原样；
  `dict get $opts -errorcode` 拿错误类别（`POSIX ENOENT` = 文件不存在、`ARITH DIVZERO` = 除零）
- **别读报错文字猜原因**：命令名写错会伪装成 `expected boolean value`（错 #18）
- `puts "DEBUG: $x"` 定点打印 → **看完立刻删**，留着会破 19/0
- `git diff --stat`：证明"只改了我以为的那几行"，也是"有没有保存"的客观判据（错 #1）
- `dict keys` / `dict exists`：取键前先看一眼，比背键表可靠
- `powershell -ExecutionPolicy Bypass -File .\tests\verify_baseline.ps1`：一条命令出三份
  `script_exit` + `fc_exit`，判据 `PASS: 3 FAIL: 0`（`fc` 退出码 `0`=一致 `1`=内容不同 `2`=文件打不开）

### 10. 马上要用（Gate 3-5）

| 语法 | 用途 | 注意 |
|---|---|---|
| `glob -nocomplain $dir/*.rpt` | 展开目录下的文件 | `-nocomplain` 避免"没匹配就报错"；返回完整路径 |
| `file join $dir $name` | 拼路径 | 别手写分隔符 |
| `lsort -command cmp $list` | 自定义排序 | `cmp` 收**两个元素**，返回 `<0 / 0 / >0` |
| `source [file join [file dirname [info script]] lib.tcl]` | 加载库 | 必须用 `info script` 推路径，**不能用 cwd**（`exec` 调用时 cwd 不确定） |
| `file normalize $p` | 绝对化、消掉 `..` | 比较路径前先做 |

### 11. 总表：语法 → 我踩过的坑

| 语法 | 对应错误 |
|---|---|
| 命令替换漏 `[]` / 写成 `()` | #2 |
| `if{` / `expr{` / `}else{` 缺空格 | #3 |
| 表达式或 `list`/`return` 里漏 `$`（打出变量名本身） | #4、#22 |
| 整数除法 `*5/9` | #5 |
| 正则 `\s` 写成非 `\s+` | #6 |
| 正则用双引号包 | #6 |
| 正则里写 `{\S+}` | #7 |
| `exit` 写进循环 / 在 `close` 之前 | #8 |
| 契约字段名大小写、单复数（`WORST_path`、`path` vs `paths`） | #9、#16 |
| 命令名写错 → 报错伪装成 `expected boolean value` | #18 |
| `[]` 里的换行不是续行 | #19 |
| 粘贴时 `set` 落进别的 proc | #20 |
| `dict get` 取错对象 | #21 |
| `join` / `dict get` 的结果没人接（白算） | #22 |
| `lindex` / `lassign` 越界 → 空串 | #22 |
| 伪代码（`open .... w`）粘进代码 | #23 |
| `exit=1` 但屏幕输出正常（未捕获错误） | #24 |

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
6. **屏幕输出正常但 `exit=1`** → 错误在最后一个 `puts` 之后（多半是写文件那段），**先看 stderr 原话**（错 #24）；
   PowerShell 有时把 stderr 混在后面，用 `2>&1 | Select-String 'couldn|error'` 筛
7. **变量莫名其妙是空的**（报错里出现 `""`）→ 查三处：`lindex` 下标越界、`dict get` 用了不存在的键、
   变量名拼错或漏 `$`（错 #22）。**不要先去查文件系统**
8. **验基线只跑一条命令**：`powershell -ExecutionPolicy Bypass -File .\tests\verify_baseline.ps1`
   → 三行 `script_exit` / `fc_exit`，判据 `PASS: 3 FAIL: 0`。比手打 `fc` 少犯路径错
   （`fc` 退出码：`0`=一致 `1`=内容不同 `2`=文件打不开）

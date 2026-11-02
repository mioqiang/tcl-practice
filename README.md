# tcl-practice —— W3 Tcl 练习包（10.12-10.18）

这是 W3「Tcl 集中入门」的练习素材：**mock 数据 + 填空骨架 + 参考实现 + 自动测试**。
所有数据都是我自己编的练习数据，**不是任何真实工具的时序结果**，不能写进简历。

---

## 0. 先解决「在哪里写 Tcl」

| 方式 | 怎么做 | 适合 |
|---|---|---|
| **A. 本机（推荐，零安装）** | 用 Python 自带的 Tcl 8.6：`python tools\tclsh.py 脚本.tcl` | 每天写练习、跑解析器 |
| **B. Linux/WSL** | `sudo apt install tcl` 后用 `tclsh 脚本.tcl` | 和真实 EDA 环境一致 |
| **C. 浏览器** | EDA Playground / tcl.tk 的 playground，见文末网址 | 出门只有平板时 |

本包用 A 验证通过：`tclsh.py` 在 Windows 上把 Tcl 的 stdin/stdout/stderr 桥接到
Python，并还原了 `argv/argc`、`exit` 退出码、`exec`。缺点：没有 Tk 图形界面，
没有 Tcllib 扩展包（本阶段用不到）。

### 两种跑法

```bat
:: 在 question 目录下（本包所在目录的上一级）
python tools\tclsh.py tcl-practice\tests\run_tests.tcl
python tools\tclsh.py tcl-practice\solutions\log_summary.tcl tcl-practice\fixtures\test_run.log
```

装到桌面（想放进自己的 Git 仓库时用一次即可）：

```powershell
cd C:\Users\jyd10\Desktop\question
powershell -File .\install-to-desktop.ps1
```

---

## 0.5 用什么编辑器

本包自带 `.vscode/` 配置（UTF-8、LF、Tab=4、`.tcl` 语法关联），并预置了 4 个任务：

| 快捷键 | 作用 |
|---|---|
| `Ctrl+Shift+B` | 跑 `tests/run_tests.tcl`（默认生成任务） |
| `Ctrl+Shift+P` → `Tasks: Run Task` | 跑当前文件 / 解析日志 fixture / 解析时序报告 fixture |
| `` Ctrl+` `` | 打开集成终端，就在 `tcl-practice` 目录，可直接敲 `python ..\tools\tclsh.py ...` |

**先试你机器上已有的**（都自带扩展市场，无需再下载）：

```powershell
# Qoder（VS Code 内核，已装 Python/ESP-IDF/Clangd 扩展）
& 'D:\Ai\Qoder\bin\code.cmd' C:\Users\jyd10\Desktop\question\tcl-practice

# Windsurf
& 'D:\Ai\Windsurf\Windsurf.exe' C:\Users\jyd10\Desktop\question\tcl-practice
```

在扩展面板（`Ctrl+Shift+X`）搜 `Tcl` 装一个即可。**注意别装错**（我查过 Marketplace 的真实条目）：

| 扩展 ID | 说明 |
|---|---|
| `bitwisecook.tcl-lsp` | **推荐**。Tcl/Tk、iRules、**EDA-Tools**，带 LSP（跳转/补全/语法检查） |
| `bitwisecook.tcl` | 旧版，Marketplace 标题已标 `[DEPRECATED]`，别装 |
| `rashwell.tcl` / `bkromhout.vscode-tcl` | 轻量，只有语法高亮 |

扩展面板里搜 Tcl 会同时看到这几个，**认 ID（发布者.名字），不要只看名字**——同名的一大堆。

想装标准 VS Code（可选；装了就和教程/截图完全一致）：

```powershell
winget install --id Microsoft.VisualStudioCode -e
```

或浏览器打开 <https://code.visualstudio.com/download> 选 Windows User Installer。
装完建议加：Tcl 扩展（同上）、中文语言包 `MS-CEINTL.vscode-language-pack-zh-hans`、
Python 扩展（W10 之后写 `run_regression.py` 用）。

---

## 1. 目录结构

```text
tcl-practice/
├── README.md                     ← 你正在看的文件
├── basics/
│   ├── 01_basics.tcl             ← 周一：变量替换 / expr / 引号与花括号
│   ├── 02_list_string.tcl        ← 周二：list / string / 解析一行日志
│   └── 03_proc_control.tcl       ← 周三：if / foreach / switch / proc / 作用域
├── fixtures/                     ← mock 练习数据（明确标注，非真实结果）
│   ├── test_run.log              ← 25 行测试日志（含 SKIP 和 5 个 FAIL）
│   ├── timing_normal.rpt         ← 6 条路径，3 条负 slack
│   ├── timing_clean.rpt          ← 4 条路径，全正 slack（WNS=0 场景）
│   └── timing_malformed.rpt      ← 坏数据：N/A、缺 Endpoint、缺 slack 行
├── solutions/                    ← 参考实现（先自己写，卡住再对照）
│   ├── log_summary.tcl
│   └── report_summary.tcl
├── parser-design.md              ← W4 交付：输入假设 / 正则 / 数据结构 / 14 条已知限制
├── tools/
│   └── tclsh.py                  ← 仓库自带一份（clone 下来即可跑，不依赖上级目录）
└── tests/
    ├── run_tests.tcl             ← 一条命令跑完 53 项断言，失败退出码非 0
    ├── verify_baseline.ps1       ← 三份 fixture 与基线逐字节比对（fc 退出码全 0 才算过）
    └── baseline/                 ← W3 基线（timing_*.txt，UTF-16LE）
```

> **可独立运行**：`tools/tclsh.py` 和 `tests/baseline/` 都在仓库里，
> `git clone` 到任意目录后直接 `python tools\tclsh.py tests\run_tests.tcl` 就能跑（53 条断言）。
> 两个脚本都会优先找仓库内的路径，找不到再回退到工作区布局（`..\tools\`、`..\.w4-baseline\`）。

---

## 2. 七天怎么用

| 日期 | 做什么 | 验收 |
|---|---|---|
| 周一 | 填 `basics/01_basics.tcl` 的 TODO | 每个 TODO 都能跑出期望值 |
| 周二 | 填 `basics/02_list_string.tcl` | `parse_line` 返回 6 个字段 |
| 周三 | 填 `basics/03_proc_control.tcl` | 不用全局变量也能统计 PASS/FAIL |
| 周四 | 写 `log_summary.tcl`（先别看 solutions） | `test_run.log` 输出 19/5/1 |
| 周五 | 学 `regexp`，写 `report_summary.tcl` | 三种报告都能处理 |
| 周六 | 整合、输出 CSV | 见下面「加练」 |
| 周日 | 删掉文件闭卷重写 + 跑 `run_tests.tcl` | PASS: 19  FAIL: 0 |

跑测试：

```bat
python ..\tools\tclsh.py tests\run_tests.tcl
```

`run_tests.tcl` **默认**测 `solutions/` 里的参考实现。做完练习后必须把测试指向自己的文件，
否则跑出来的 `PASS: 19` 全是参考实现的成绩，不是你的。

本工作区的实际做法：改 `tests/run_tests.tcl` 里两处 `set script`，把 `$solutions` 换成 `$root`。

```tcl
set script [file join $root log_summary.tcl]       ;# 原先：$solutions
set script [file join $root report_summary.tcl]    ;# 原先：$solutions
```

`$root` = `tcl-practice` 目录本身（`run_tests.tcl:44` 算出），`$solutions` = `<root>/solutions`。

⚠️ **这两处要一起改**：只改第一处的话，`log_summary` 那 7 条是你的，`report_summary`
那 12 条仍然是参考实现的——总分 19 看着漂亮，实际只有 7 条在验你的代码。

当前基线：**PASS: 53  FAIL: 0**（2026-11-02 实测；19 条原有 + 27 变体 + 5 批量 + 2 错误路径）。
每次改完跑两条：`python ..\tools\tclsh.py tests\run_tests.tcl` 和
`powershell -ExecutionPolicy Bypass -File .\tests\verify_baseline.ps1`（后者逐字节比 3 份 W3 基线）。

### 实测记录（2026-10-20，本机实际运行结果）

**环境**：Windows + Python 3.12（`tools/tclsh.py` 内嵌 Tcl 8.6.13），工作目录 `tcl-practice`。
**数据**：全部是 `fixtures/` 里的 mock 练习数据，**不是任何真实工具的输出**。

```text
$ python ..\tools\tclsh.py log_summary.tcl fixtures\test_run.log
失败用例: tc_fifo_overflow tc_uart_baud_mismatch tc_crc_double_bit tc_axil_illegal_addr tc_fifo_overflow
PASS: 19
FAIL: 5
SKIP: 1
$ echo "exit=$LASTEXITCODE"
exit=2
```

```text
$ python ..\tools\tclsh.py report_summary.tcl fixtures\timing_normal.rpt
FILE: timing_normal.rpt
DESIGN: timer_uart_top
CORNER: slow_125c_1v08
WNS: -0.483
TNS: -0.757
VIOLATIONS: 3
WORST_PATH: u_core/reg_shift_q[0] -> u_core/reg_shift_q[5]  slack = -0.483
PATHS: 6
INVALID: 0
$ echo "exit=$LASTEXITCODE"
exit=0
```

三种报告的汇总（实测与期望一致）：

| 文件 | PATHS | VIOLATIONS | WNS | TNS | INVALID | 退出码 |
|---|---:|---:|---:|---:|---:|---:|
| timing_normal.rpt | 6 | 3 | -0.483 | -0.757 | 0 | 0 |
| timing_clean.rpt | 4 | 0 | 0.000 | 0.000 | 0 | 0 |
| timing_malformed.rpt | 2 | 0 | 0.000 | 0.000 | 3 | 2 |

```text
$ python ..\tools\tclsh.py tests\run_tests.tcl
...
PASS: 19   FAIL: 0
全部通过
```

**已知的输出瑕疵**（不影响断言，暂不修）：
- `WORST_PATH:` 那行等号两边有空格（`slack = -0.483`），契约示例写的是 `slack=-0.483`；
- 无违例的报告中 `WORST_PATH:  ->   slack = 0.000` 的两个路径名是空的。

### 实测记录（2026-11-02，W4 收工）

`report_summary.tcl` 已拆成 `parse_report` / `compute_summary` / `format_row` / `write_csv`，
新增批量目录模式、CSV 落盘、9 条格式变体和 34 条断言。**单文件模式的 9 行输出与 W3 基线逐字节一致**
（`.w4-baseline/` 的 `fc_exit` 全 0），所以上面的 2026-10-20 记录仍然有效。

```text
$ python ..\tools\tclsh.py report_summary.tcl fixtures
MODE: batch
DIR: fixtures
FILE                          PATHS  VIOLATIONS       WNS       TNS
timing_clean.rpt                  4           0     0.000     0.000
timing_malformed.rpt              2           0     0.000     0.000
timing_normal.rpt                 6           3    -0.483    -0.757
TOTAL: 3 files, 3 violations, 3 invalid
$ echo "exit=$LASTEXITCODE"
exit=2
```

```text
$ python ..\tools\tclsh.py tests\run_tests.tcl
...
PASS: 53   FAIL: 0
全部通过
```

变体（`fixtures/variants/`，每条只偏离基准一处，验证"不会静默算错"）：

| 变体 | paths | invalid | 退出码 | 验证点 |
|---|---:|---:|---:|---|
| v_canonical | 1 | 0 | 0 | 基准 |
| v_unit_ns | 1 | 0 | 0 | `-0.300ns` 单位可剥 |
| v_slack_case | 2 | 0 | 0 | `Slack` 大写不再丢路径 |
| v_missing_slack_mid | 1 | 1 | 2 | 中间路径缺 slack 行 → 计入 invalid |
| v_missing_endpoint | 0 | 1 | 2 | 缺 Endpoint |
| v_na | 0 | 1 | 2 | `N/A` 判无效 |
| v_plus_sign | 1 | 0 | 0 | `+0.120` 合法 |
| v_thousand | 0 | 1 | 2 | 千分位判无效 |
| v_multi_space | 1 | 0 | 0 | 多空格不错位 |

完整设计说明（输入假设、正则、数据结构、14 条已知限制）见 [`parser-design.md`](parser-design.md)。

### 自动补全的开关（练习模式 vs 查 API 模式）

`bitwisecook.tcl-lsp` 会在你打 `set` / `str` / `regexp` 时把命令名和参数提示弹出来，
等于把答案送到眼前，破坏「关掉资料重写」那一环。所以本工作区默认**关掉**自动补全。

三个文件的分工：

| 文件 | 作用 |
|---|---|
| `.vscode/settings.json` | **当前生效**的设置（由脚本切换，别手改） |
| `.vscode/settings.off.json` | 练习模式：补全全关 |
| `.vscode/settings.on.json` | 查 API 模式：补全全开 |

切换（在 `tcl-practice` 目录下）：

```powershell
powershell -ExecutionPolicy Bypass -File .\toggle-suggest.ps1 status   # 看现在是哪种
powershell -ExecutionPolicy Bypass -File .\toggle-suggest.ps1 off      # 练习模式
powershell -ExecutionPolicy Bypass -File .\toggle-suggest.ps1 on       # 查 API 模式
powershell -ExecutionPolicy Bypass -File .\toggle-suggest.ps1          # 直接切换
```

**最省事的临时办法**：练习模式下想查一次，直接按 `Ctrl+Space` 手动叫出补全，
查完继续自己写——这叫「主动查」，和它主动喂给你是两回事。

想在界面里改也行：`Ctrl+Shift+P` → `Preferences: Open Workspace Settings (JSON)`，
把 `editor.suggestOnTriggerCharacters` 改成 `true` 即开启。

> 注意：本工作区设置**只对 `tcl-practice` 文件夹生效**，其他项目不受影响。
> 想让所有项目都开补全：`Ctrl+Shift+P` → `Preferences: Open User Settings (JSON)`，
> 那是全局设置。

---

## 3. 数据格式（写解析器前先定契约）

### 3.1 测试日志 `fixtures/test_run.log`

```text
2026-10-15 09:12:03 INFO  tc_reset_smoke         PASS  12
    日期       时间    级别    用例名              结果  耗时(ms)
```

- 字段之间**可能是多个空格**，所以不要用 `split` 硬拆，用一条 `regexp` 抓 6 个组；
- 第 18 行的结果是 `SKIP`，专门测「遇到未知状态怎么办」；
- 期望：总数 25 / PASS 19 / FAIL 5 / SKIP 1，退出码 2（因为有 FAIL）。

### 3.2 时序报告 `fixtures/timing_*.rpt`

每条路径由 `Startpoint:` 开头，关键行：

```text
Startpoint: u_core/reg_shift_q[0]        ← 真正名字在下一行，别把括号说明当名字
Endpoint:   u_core/reg_shift_q[5]
  slack (VIOLATED)                                          -0.483
```

- `slack` 行：`slack (MET|VIOLATED)  <值>`；
- 设计名/工艺角在文件头注释：`# 设计: xxx   工艺角: xxx`（注意：正则里
  字面量竖线要写成 `\|`，否则会被当成「或」——这是我写参考实现时踩到的坑）；
- 期望结果：

| 文件 | PATHS | VIOLATIONS | WNS | TNS | 退出码 |
|---|---:|---:|---:|---:|---:|
| timing_normal.rpt | 6 | 3 | -0.483 | -0.757 | 0 |
| timing_clean.rpt | 4 | 0 | 0.000 | 0.000 | 0 |
| timing_malformed.rpt | 2 | 0 | 0.000 | 0.000 | **2** |

坏数据里 `INVALID` 应为 3：`N/A` 非数字、缺 `Endpoint`、缺 `slack` 行。
**能正确报错，比能把错误数据算出数更重要。**

---

## 4. 输出契约（`run_tests.tcl` 依赖这些字段名）

```text
FILE: timing_normal.rpt
DESIGN: timer_uart_top
CORNER: slow_125c_1v08
WNS: -0.483
TNS: -0.757
VIOLATIONS: 3
WORST_PATH: u_core/reg_shift_q[0] -> u_core/reg_shift_q[5]  slack=-0.483
PATHS: 6
INVALID: 0
```

退出码约定：`0` 成功；`1` 用法/文件不存在/空文件；`2` 数据里有问题（FAIL 或无效路径）。

### 4.1 批量模式（W4 新增，参数是目录）

```text
MODE: batch
DIR: fixtures
FILE                          PATHS  VIOLATIONS       WNS       TNS
timing_clean.rpt                  4           0     0.000     0.000
timing_malformed.rpt              2           0     0.000     0.000
timing_normal.rpt                 6           3    -0.483    -0.757
TOTAL: 3 files, 3 violations, 3 invalid
```

- 文件顺序由 `lsort` 保证（**顺序也是契约**，CSV 行序可断言）；
- 批量退出码：任一文件有无效路径 → `2`；目录里没有 `.rpt` → `1`；
- 单文件模式的 9 行输出**不受影响**（`tests/verify_baseline.ps1` 逐字节比对）。

### 4.2 CSV（8 列）

```text
file,design,corner,wns,tns,violations,worst_start,worst_end
timing_clean.rpt,fifo_sync_top,fast_0c_1v32,0.000,0.000,0,,
```

无违例时最后两列是空字段，**逗号不能少**。默认写 `out/summary.csv`，可用第二个参数覆盖。
设计说明与已知限制见 [`parser-design.md`](parser-design.md)。

---

## 5. 加练（周六、以及 W4 的接口）

1. **批量目录**：让 `report_summary.tcl` 接收一个目录，用 `glob *.rpt` 遍历；
2. **CSV 输出**：加 `write_csv` 过程，列 = `file,design,corner,wns,tns,violations,worst_start,worst_end`；
3. **排序**：用 `lsort -command` 按 slack 升序打印所有违例路径；
4. **格式容错**：自己动手改 fixture，加单位（`-0.483ns`）、加千分位、把 `slack` 写成 `Slack`，
   看解析器会不会静默算错；
5. **换成真数据**：W18 用 Yosys/OpenSTA 生成真实报告后，**同一套解析器**直接复用，
   只改正则。这是这周练习的真正目的。

---

## 6. Bug 记录（每周至少 1 条，这是验收项）

| 日期 | 现象 | 根因 | 修复 | 预防 |
|---|---|---|---|---|
| 10.15 | 统计把 SKIP 记成 FAIL | `switch` 没写 `default`，落到 else 分支 | 加 `default` 并在输出里单列 SKIP | 每个枚举字段都显式列出合法值 |
| 10.16 | WNS 算出 0 但报告明显违例 | 用 `string compare` 比较 slack 字符串 | 用 `expr {double($slack) < 0}` | 数值一律先 `string is double -strict` 校验 |
| 10.16 | 工艺角永远是 UNKNOWN | 正则里 `|` 没转义 | 写成 `\|` | 正则里所有字面量元字符都转义 |
| 10.18 | 空文件检查失效，空文件退出码 0 | 复制上一块 `if`，`file exists` 没改成 `file size` | 改成 `[file size $path] == 0` | 复制条件块后逐字核对**命令名**，不只核对变量名 |
| 10.18 | 有 FAIL 时只输出一个 `exit=2`，屏幕全空 | `exit 2` 写在 `while` 循环内，读到第一条 FAIL 就终止进程 | 退出码判断移到所有 `puts` 之后 | 打印和退出码是两个交付物，`puts` 必须先执行完 |
| 10.18 | SKIP 统计不到（总数 24，不报错） | 正则写成 `(PASS\|FAIL)`，漏了 `SKIP` | 补成 `(PASS\|FAIL\|SKIP)` | 正则的枚举值和 `switch` 分支一一对应检查 |
| 10.19 | malformed 的 TNS = 17.908（正的 slack 也被累加） | 单行 `if {$v < 0} {incr VIOLATIONS}` 只包住一条语句，`set TNS` 落在 if 外面 | TNS 累加挪进负值分支 | 同一条件管多条语句时写多行块，不用单行 `if` |
| 10.19 | normal/clean 的 `INVALID` = 1、退出码 2 | 结算后没清 `cur_start`，被文件末尾的「悬空路径」检查重复计数 | 结算完立刻清空状态变量 | 状态机的「结算」和「复位」写在一起；用有/无合法路径两种数据都测 |
| 10.20 | `format %.3f $v` 报 `expected floating-point number but got "u_uart/reg_baud_q[3]"` | 循环变量 `v` 在循环结束后仍存在，拿到的是最后一次匹配值 | 输出改用语义变量 `$WNS` | 循环外不要复用循环变量名 |
| 10.20 | 闭卷重写后三个计数器全 0，一行都没匹配 | 正则写成 `{\S+}`——花括号在正则里是元字符，变成要求日志里真有 `{ }` | 改回圆括号分组 `(\S+)` | 正则外层花括号已负责「不替换」；改完先用一行真数据 `regexp` 验一次 |
| 10.20 | 「最差路径起点」断言失败，但肉眼看是对齐的 | 输出写成 `WORST_Path:`，测试正则区分大小写 | 改成 `WORST_PATH` | 契约字段名复制粘贴，不要凭记忆敲；用 `regexp` 验证而不是肉眼看 |
| 10.20 | `extra characters after close-quote` | `puts` 的字符串中间多了一个引号，字符串提前闭合 | 一对引号包到行尾 | 长 `puts` 写完后数一遍引号（必须是偶数且两两配对） |

（10.15-10.16 三条来自参考实现；10.18 之后是我自己写两个解析器时真实踩到的。）

---

## 7. 练习网址（每条都实际抓取验证过，2026）

### 7.1 浏览器里直接写 Tcl（零安装）

- **官方 Tcl Playground（CloudTk + Tcl/Tk 9）**：<https://wiki.tcl-lang.org/page/Tcl+Playground>
  Tcl 8 入口：<https://cloudtk-app.tcl-lang.org/cloudtk/VNC?session=new&Tk=Tcl-Playground-Tcl8>
  唯一能在浏览器里跑 **Tk 图形界面**的官方 playground，页面 2026-06-28 仍更新。
- **EmTcl（客户端运行，Tcl 8.6 + Jim Tcl）**：<https://aidanhs.github.io/emtcl/>
  零安装 REPL，Ctrl+Enter 交互；不能保存/分享代码。
- **Try It Online**：<https://tio.run/> 支持 permalink 分享代码；Tcl 版本号未核实。
- ⚠️ **Wandbox 不支持 Tcl**，别浪费时间。

### 7.2 有习题、有反馈（主力）

- **Exercism Tcl Track（首推）**：<https://exercism.org/tracks/tcl> 中文界面 <https://exercism.org/zh-CN/tracks/tcl>
  **135 道题 + 自动判分 + 52 位志愿者真人批改 + 免费**，是目前唯一同时具备这三样的 Tcl 题集。
  和这周的练习分工：Exercism 练 string/list/dict 手感，本包的 fixtures 练「真实报告解析」。
- **Tcler's Wiki 官方教程（Clif Flynt，约 50 课）**：<https://wiki.tcl-lang.org/page/Tcl+Tutorial+Lesson+0>
  系统打底用；本周重点跳读 list / string / 正则 / dict / file I/O 那几课。
- **Rosetta Code 的 Tcl 分类（1005 个任务）**：<https://rosettacode.org/wiki/Category:Tcl>
  最适合「同一个题目对比 Python 写法」，学惯用法。
- **TutorialsPoint Tcl/Tk（速查）**：<https://www.tutorialspoint.com/tcl-tk/index.htm>

### 7.3 手册（EDA 工具普遍还是 Tcl 8.6，先看 8.6）

- **Tcl 8.6 命令参考**：<https://www.tcl-lang.org/man/tcl8.6/TclCmd/contents.htm>
- Tcl 9.0 文档：<https://www.tcl-lang.org/man/tcl9.0/>
- ⚠️ **`www.tcl.tk` / `tcl.tk` 域名已解析失败，统一改用 `www.tcl-lang.org`**；
  `.../man/tcl8.6/` 目录形式是 404，必须走上面的 `TclCmd/contents.htm`。
- **OpenROAD 文档（Tcl + Python 双 binding，交互式 Tcl 解释器）**：
  <https://openroad.readthedocs.io/en/latest/main/README.html>

### 7.4 EDA 实操环境（写 Tcl 处理真实 timing report）

- **EDA Playground**：<https://www.edaplayground.com/>
  关键结论：**它没有 OpenSTA**。Tcl 的真实入口是各仿真器的 `run.do`（Questa/VCS/Xcelium 的
  run.do 就是 Tcl），可在浏览器里写 Tcl 控制仿真；Yosys 用的是 `run.ys`（Yosys 自有脚本，**不是 Tcl**）。
  已核对支持：Verilator v5.044、Yosys 0.37、Icarus 12.0、GHDL 5.1.1，以及 UVM 1.2 / IEEE 1800.2-2017。
  → **W15 的 UVM mini-case 就用它，符合周表里「只有开源工具」那条分支。**
- **OpenSTA（Tcl 驱动，报 timing report 的正主）**：<https://github.com/parallaxsw/OpenSTA>
- **OpenROAD-flow-scripts**：<https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts>
  （支持 SKY130/GF180/Nangate45/ASAP7；入门 URL 与 Docker 细节尚未核实）
- 想在 Windows 上装 Yosys：MSYS2 里有 `mingw-w64-ucrt-x86_64-yosys` 包，
  <https://packages.msys2.org/packages/mingw-w64-ucrt-x86_64-yosys>
  （该构建是否启用 Tcl 支持需自己试 `yosys -c "tcl help"`）。

### 7.5 想装一个独立 tclsh（可选，W4 之后再说）

- **Magicsplat Tcl/Tk for Windows（免费）**：<https://www.magicsplat.com/tcl-installer/index.html>
  1.18.0 = Tcl/Tk 8.6.18；2.0.7 = Tcl/Tk 9.0.4；自带 tcllib 2.0、tdom、tdbc 等。
- MSYS2：`pacman -S mingw-w64-ucrt-x86_64-tcl`（8.6.18）
- Linux/WSL：`sudo apt install tcl`（包名未核实）
- 本包的 `tools/tclsh.py` 就是「不装任何东西」的替代方案，已核对内嵌 **Tcl 8.6.13**，
  覆盖本包全部练习（差异见第 0 节）。

> 说明：本节标注「未核实」的项，是调研时抓取失败或需登录，不代表不能用，用之前自己点一下。


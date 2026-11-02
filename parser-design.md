# parser-design.md —— 时序报告解析器 v1 设计说明

> 状态（2026-11-02）：**已完成**。自动断言 **53 条**、格式变体 **9 条**、W3 基线 **3 份逐字节一致**。
> 本文是**契约**：改解析器行为之前先改这里。
> 写作判据：一个没参与过的人，看这份文档 + `report_summary.tcl`，能在 90 分钟内改正则去适配一份格式相近的新报告（= W4 的 M1 验收）。

---

## 1. 目的与范围

**做**：把 mock / OpenSTA 风格的时序报告（`.rpt`）解析成结构化数据（dict + 嵌套 list），输出

- 单文件：9 行 `KEY: value` 到 stdout；
- 批量：每个 `.rpt` 一行表格 + 一行 `TOTAL`；
- 两者都写一份 8 列 CSV（表头 + N 行）。

**不做**（明确划出边界，避免范围膨胀）：

- netlist / SDC / SDF 解析；
- 多 corner、多 path group 的合并与对比；
- Markdown / HTML 报告、图形界面；
- 真实 OpenROAD/OpenSTA 报告的适配（W18 再做，届时**只改正则，不动数据结构**）。

---

## 2. 输入假设

每一条都写清"不满足会怎样"——这是这份文档最实用的部分。

| # | 假设 | 不满足的后果 |
|---|---|---|
| A1 | 文件里有 `设计:` 与 `工艺角:`，冒号后至少 1 个空白 | 输出 `UNKNOWN`（**不报错**） |
| A2 | 一条路径 = `Startpoint:` 行 → `Endpoint:` 行 → `slack (MET\|VIOLATED) 值` 行 | 缺 `slack` 行 → 该路径计入 `INVALID` |
| A3 | 关键字在**行首**（行首空白会先被 `trim` 掉） | 前面有别的字符 → 不匹配 → 可能静默少算 |
| A4 | `Startpoint` / `Endpoint` **大小写敏感**，冒号紧跟关键字 | 写成 `StartPoint:` 或 `Endpoint :` → 不匹配 |
| A5 | `slack` **大小写不敏感**；`slack` 与 `(` 之间、`)` 与值之间空白任意（空格/Tab 都行） | 已容忍（见 `v_slack_case` / `v_multi_space`） |
| A6 | 值是 `±浮点` 或 `±浮点+字母后缀`（时间单位） | `N/A`、`1,234.567` → `INVALID` |
| A7 | 一行一条记录，**不跨行** | 跨行写法会漏 |
| A8 | 一条路径只出现**一条** `slack` 行 | 多出的一条会被计成 `INVALID`（见限制 L6） |
| A9 | 文件 UTF-8；CRLF 由 Tcl 的 `-translation auto` 自动归一 | 其他编码 → 中文头信息解析不出来 |

---

## 3. 正则清单

全部在 `parse_report` 里（`report_summary.tcl`）。

| 用途 | 正则 | 说明 / 踩过的坑 |
|---|---|---|
| Startpoint | `{^Startpoint:\s+(\S+)}` | `^` 必须有：否则会误匹配路径明细表里同名的字符串 |
| Endpoint | `{^Endpoint:\s+(\S+)}` | 冒号必须紧跟关键字，`Endpoint :` 不认（限制 L4） |
| slack 行 | `{-nocase slack\s+\((?:MET\|VIOLATED)\)\s+(\S+)}` | ① `-nocase` 解决 `Slack` 大写（曾静默丢路径）② `slack\s+\(` **不能写成 `slack \s+\(`**——`{}` 里的空格是字面空格，多打一个就要求两个空白，一条都不匹配 ③ `(?:...)` 是非捕获组，避免多一个捕获变量 ④ 字面竖线要写成 `\|` |
| 设计 | `{设计:\s+(\S+)}` | 不锚定行首，注释里的 `设计:` 也能抓 |
| 工艺角 | `{工艺角:\s+(\S+)}` | 同上；取**最后一次**出现（限制 L13） |
| 单位剥离 | `regsub {[A-Za-z]+$} $raw ""` | `-0.300ns` → `-0.300`；不校验单位种类（限制 L3） |

**四条铁律**（每一条都对应一次真实 bug）：

1. 正则一律用 `{}` 包——双引号会把 `\d` 吃成 `d`；
2. 空白一律 `\s+`，不要 `\s`；
3. 分组只用 `(...)` / `(?:...)`，写 `{\S+}` 是"要求文本里真有花括号"；
4. **改完先用一行真数据单独 `regexp` 验一次**再放进循环——正则写错不会报错，只会"一条都不匹配"。

---

## 4. 数据结构与状态机

### 4.1 两个 dict（`dict get` 缺键 = 报错，不是空串）

| dict | 产出者 | 键 | 消费方 |
|---|---|---|---|
| `report` | `parse_report` | `design` `corner` `records` `invalid` | `format_row`、退出码、批量表格 |
| `summary` | `compute_summary` | `wns` `tns` `violations` `worst_start` `worst_end` `paths` | `format_row`、单文件 9 行、批量表格 |

### 4.2 `records` = 嵌套 list

```text
records = { {start1 end1 slack1} {start2 end2 slack2} ... }
             └── 每条路径一个三元组 ──┘
```

- `slack` 存的是**剥掉单位后的原始字符串**（如 `-0.483`），不是 double；
- 格式化（`format %.3f`）**只在输出层做**，`format_row` 和屏幕输出各做一次；
- `paths = llength records`，让"计数"和"明细"同源，不可能漂移。

### 4.3 状态机（三个变量 + 三条结算规则）

```text
cur_start  当前路径起点，"" 表示没有待结算的路径
cur_end    当前路径终点
INVALID    无效路径计数
```

| 事件 | 处理 |
|---|---|
| 命中 `Startpoint:` | 若 `cur_start` 非空 → 上一条没走到 slack 行 → `INVALID++`（**结算规则 1**）；然后重置 `cur_start` / `cur_end` |
| 命中 `Endpoint:` | `cur_end = 值`（后出现的覆盖先出现的，不报错，限制 L7） |
| 命中 slack 行 | 若 `cur_start`、`cur_end` 都非空 **且** 值能转 double → `lappend records`；否则 `INVALID++`。**无论哪种都清空状态**（结算规则 2） |
| 文件结束 | 若 `cur_start` 仍非空 → `INVALID++`（结算规则 3，兜住最后一条） |

### 4.4 不变式（验收的核心）

> **`paths + invalid` == 文件里 `Startpoint:` 的行数**

含义：任何一条路径都有确定去向，**不许消失**。这条不变式在 3 份 fixture + 9 条变体上全部成立（`tests/run_tests.tcl` 里的变体断言即按此设计）。
例外：同一路径出现多条 slack 行时会破（限制 L6）。

---

## 5. 输出契约

### 5.1 单文件模式（参数是文件）

```text
FILE: timing_normal.rpt
DESIGN: timer_uart_top
CORNER: slow_125c_1v08
WNS: -0.483
TNS: -0.757
VIOLATIONS: 3
WORST_PATH: u_core/reg_shift_q[0] -> u_core/reg_shift_q[5]  slack = -0.483
PATHS: 6
INVALID: 0
```

- 这 9 行是**被 `tests/verify_baseline.ps1` 逐字节比对**的，一个字符都不能改；
- 已知瑕疵：`slack = -0.483` 等号两边有空格（契约示例写的是 `slack=-0.483`），无违例时 `WORST_PATH` 两个名字为空（限制 L11/L12）。

### 5.2 批量模式（参数是目录）

```text
MODE: batch
DIR: fixtures
FILE                          PATHS  VIOLATIONS       WNS       TNS
timing_clean.rpt                  4           0     0.000     0.000
timing_malformed.rpt              2           0     0.000     0.000
timing_normal.rpt                 6           3    -0.483    -0.757
TOTAL: 3 files, 3 violations, 3 invalid
```

- `glob -nocomplain [file join $dir *.rpt]` + **`lsort`**：排序是契约的一部分（文件顺序稳定，CSV 行序才可断言）；
- 表头只打一次；`TOTAL` 行可被 `regexp` 直接断言；
- 每次运行都截断重写 CSV（`w` 模式），所以不会出现重复行。

### 5.3 CSV（8 列，按列序）

```text
file,design,corner,wns,tns,violations,worst_start,worst_end
timing_clean.rpt,fifo_sync_top,fast_0c_1v32,0.000,0.000,0,,
```

- `file` 列是**文件名**（`file tail`），不是完整路径；
- 无违例时最后两列是空字段，**逗号不能少**（否则列错位且不报错）；
- 用 `join $row ,` 拼行；直接 `puts $fh $row` 会把 list 写成带花括号的形式。

### 5.4 退出码

| 码 | 单文件 | 批量 |
|---|---|---|
| `0` | 成功 | 所有文件都没有 invalid |
| `1` | 用法错误 / 路径不存在 / 空文件 | 目录里没有 `.rpt` / 路径不存在 |
| `2` | 该报告有 invalid 路径 | **任一**文件有 invalid |

⚠️ **`1` 是双义码**：未捕获的 Tcl 错误（脚本写错了）也落在 `1`，和"用法错误"无法区分（限制 L10）。

### 5.5 用法

```text
tclsh report_summary.tcl <报告|目录> [输出CSV]
默认输出：out/summary.csv（目录不存在会自动 mkdir）
```

---

## 6. 已知限制

| # | 限制 | 现象 | 复现 | 计划 |
|---|---|---|---|---|
| L1 | 千分位不支持 | `1,234.567` → `INVALID` | `fixtures/variants/v_thousand.rpt` | 暂不修（真实报告一般不出现） |
| L2 | `N/A` 不当作 0 | 整条路径计入 `INVALID` | `v_na.rpt` | 有意为之：宁可报错也不猜测 |
| L3 | 单位只剥字母、不校验种类 | `-1.2mV` 也会被当成合法时间 | — | 可加白名单（ns/ps/fs） |
| L4 | `Endpoint :`（冒号前空格）不识别 | 整条路径 → `INVALID` | 开发时真实撞到 | 正则改 `^\s*Endpoint\s*:\s*(\S+)` 即可 |
| L5 | `Startpoint`/`Endpoint` 大小写敏感，只有 `slack` 加了 `-nocase` | 写成 `StartPoint:` → 静默少算 | 未覆盖变体 | 视真实报告决定 |
| L6 | 同一路径多条 `slack` 行 | 多出的那条计 `INVALID`，不变式被破坏（`paths+invalid > SP`） | 实测：`paths=1 invalid=1`，`SP=1` | 未覆盖；真报告不会这样 |
| L7 | 多条 `Endpoint` | 后一条覆盖前一条，不报错 | 实测：`WORST_PATH` 取到第二个 Endpoint | 可加 `INVALID` |
| L8 | CSV 无字段转义 | 层次名含 `,` 或 `"` 会切错列 | 未覆盖 | W18 接真实数据前补 RFC 4180 转义 |
| L9 | 批量模式无 per-file invalid 明细 | 只能看 `TOTAL` 的总数 | 表格见 5.2 | 需要时加一列 |
| L10 | `exit 1` 双义（未捕获错误 vs 用法错误） | 屏幕正常但 `exit=1` 时无法区分"脚本 bug"和"参数错" | Gate 1/2 各踩一次 | 可包 `catch`，用 `exit 3` 表示内部错误 |
| L11 | `WORST_PATH` 是 `slack = -0.483` | 与契约示例 `slack=-0.483` 不一致 | `verify_baseline` 基线即此格式 | 改就会破 3 份基线，暂不动 |
| L12 | 无违例时 `WORST_PATH` 两个名字为空 | 输出 `WORST_PATH:  ->   slack = 0.000` | `timing_clean.rpt` | 可改成 `-` |
| L13 | 头信息取最后一次出现 | 文件里有多组 `设计:`/`工艺角:` 时只保留最后一个 | — | 未覆盖 |
| L14 | 只支持"一条路径一组"的结构 | 多 path group / 多 corner 不分段 | — | W18 再设计 |

---

## 7. 决策记录（为什么这样选）

1. **支持单位后缀**：真实报告带 `ns` 很常见。代价是"不校验单位种类"（L3），换来"不会因为单位把整份报告判成无效"。
2. **`slack` 用 `-nocase`，`Startpoint`/`Endpoint` 不用**：`slack` 是数据关键字，各工具大小写写法不一；`Startpoint`/`Endpoint` 是我们用来划分路径结构的锚点，收紧反而安全。
3. **用 dict 而不是并行数组/字符串拼接**：取值靠名字，写错立刻 `key ... not known` 报错；字符串拼接只能靠位置记，顺序错了不报错、结果全歪。
4. **`records` 存原始字符串、格式化延后到输出层**：解析层不掺入展示决策；将来要输出 4 位小数只改输出层。
5. **`paths = llength records`**：让"计数"和"明细"同源，物理上不可能漂移。
6. **批量结果用 `lsort` 排序**：把顺序变成契约，测试才能按行号断言；否则行序随文件系统变化，diff 不可信。
7. **CSV 用 `w` 不用 `a`**：连跑两次结果相同（幂等），测试和 diff 才稳。
8. **暂不包 `catch`**：包了会把"脚本 bug"也吞成正常退出码，反而更难查（L10 留作改进点）。
9. **一套数据结构同时服务单文件与批量**：单文件只是"批量里只有一个元素"的退化情况，`format_row` / `write_csv` 完全复用。

---

## 8. 测试矩阵（53 条断言）

| 组 | 条数 | 覆盖 |
|---|---:|---|
| `log_summary` | 7 | 正常日志、文件不存在、缺参数 |
| `report_summary` 单文件 | 12 | 正常 / 无违例 / 坏数据 |
| 格式变体 | 27（9 × 退出码/PATHS/INVALID） | 见下表 |
| 批量目录 | 5 | 退出码、`TOTAL`、CSV 行数/表头/排序 |
| 错误路径 | 2 | 空目录、目录不存在 |

变体清单（`fixtures/variants/`，每条只偏离 canonical 一处）：

| 文件 | SP | paths | invalid | exit | 验证的行为 |
|---|---:|---:|---:|---:|---|
| `v_canonical.rpt` | 1 | 1 | 0 | 0 | 基准 |
| `v_unit_ns.rpt` | 1 | 1 | 0 | 0 | 单位后缀可剥 |
| `v_slack_case.rpt` | 2 | 2 | 0 | 0 | `Slack` 大写不再丢路径 |
| `v_missing_slack_mid.rpt` | 2 | 1 | 1 | 2 | 中间路径缺 slack 行 → 计 `INVALID`（曾静默丢失） |
| `v_missing_endpoint.rpt` | 1 | 0 | 1 | 2 | 缺 Endpoint |
| `v_na.rpt` | 1 | 0 | 1 | 2 | 非数字值 |
| `v_plus_sign.rpt` | 1 | 1 | 0 | 0 | `+0.120` 合法 |
| `v_thousand.rpt` | 1 | 0 | 1 | 2 | 千分位不支持 |
| `v_multi_space.rpt` | 1 | 1 | 0 | 0 | 多空格不错位 |

回归跑法：

```powershell
python ..\tools\tclsh.py tests\run_tests.tcl                          # PASS: 53   FAIL: 0
powershell -ExecutionPolicy Bypass -File .\tests\verify_baseline.ps1  # PASS: 3    FAIL: 0
```

---

## 9. 后续迭代点

- **W18 接真实 OpenSTA/OpenROAD 报告**：预期只改第 3 节的正则（真实报告的字段更多、缩进不同），第 4 节数据结构不动；
- **补 CSV 转义**（L8），接真实层次名前必须做；
- **`exit 3` 表示内部错误**（L10），把"脚本 bug"和"用法错误"分开；
- **多 corner / 多 path group**（L14）：需要新一层数据结构，届时先改本文档再改代码。

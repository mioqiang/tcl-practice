# 新会话开场提示词（复制这段给新的 AI 会话）

我在做 **W4 收尾 + W5 SystemVerilog 入门**。Tcl 项目在 `C:\Users\jyd10\Desktop\question\tcl-practice`。

**请先读这几个文件，不要让我重新贴代码：**
- `tcl-practice/NEXT-SESSION.md` 的「当前进度」+「W4 清单」（最重要，10 行看完当前状态）
- `tcl-practice/CHEATSHEET.md`（语法速查 + 21 条反复犯的错，重点看 18-21）
- `tcl-practice/README.md`（数据格式、输出契约 `:259-273`、实测记录、bug 记录）
- 周表 `C:\Users\jyd10\Desktop\codex\codex_重排逐周表_W2-W22_后端主攻.md` 的 `W4` 与 `W5 · 10.26-11.01` 两节

**我的代码与仓库状态（不要从零写）：**
- `git` 已建（10/27）：`main` = **PASS: 19  FAIL: 0**，三份 fixture 输出与 W3 基线**逐字节一致**
- `wip/w4-tcl` = 半成品：`compute_summary` 已拆出，**只差 2 处**（哪 2 处写在下面「当前进度」）
- `report_summary.tcl` 已有 `parse_report` / `compute_summary`；`write_csv` 还没写
- 测试：`python ..\tools\tclsh.py tests\run_tests.tcl` → 期望 19/0
- 回归基线：仓库内自带 `tests\baseline\timing_*.txt`（`..\.w4-baseline\` 为旧位置，脚本会先找仓库内的），
  用 `fc.exe` 比，**判据是退出码**（`fc` 无差异时也返回 0 并打印提示，别按“有没有输出”判断）

**我的环境：**
- Windows，VS Code（`D:\Microsoft VS Code`），Tcl 扩展 `bitwisecook.tcl-lsp`
- 没有 tclsh：`python ..\tools\tclsh.py <脚本> [参数]`（工作目录 `tcl-practice`；
  仓库里也带了一份 `tools\tclsh.py`，clone 下来可直接跑）
- **SV/FPGA 环境**：`SV: Vivado ML 2024.2 / XSim v2024.2.0`（本机唯一仿真器；iverilog/verilator 都没装）
  - 实测 XSim 支持 `interface`/`modport`/`clocking`/`program`/`virtual interface`/`class`/`rand`/`covergroup`（8/8）
  - 命令：`xvlog -sv` → `xelab -sv <top> -s <snap>` → `xsim <snap> -runall`（**必须 `-sv`**，文件不能带 BOM）
  - 器件：`xc7z020clg484-2`（Zynq-7020），工程 `D:\Vivado2024.2\AC880\mux2`
  - **红线**：`D:\Vivado2024.2\AC880\` 下的 Vivado 工程**只读**（不移动/不修改/不往里生成文件），
  实验一律在 sv-lab 的副本上做
- SV 练习与笔记在**另一个仓库** `C:\Users\jyd10\Desktop\question\sv-lab`（`notes\toolchain.md` 有完整矩阵）

**我的学习方式（重要，请遵守）：**
- **我自己写代码，你不要直接给答案**；给我语法用法、思路提示、验收标准
- 我卡住时会贴报错或输出，你帮我定位根因（尽量用可运行的最小演示验证，别只讲理论）
- 每次改完我要 `Ctrl+S` 保存——报错和我贴的代码对不上时请先怀疑这个
- 我贴输出时，你按 `tests/run_tests.tcl` 的断言、README 的期望值和基线 `fc` 结果验收

**我反复犯的错（请主动提醒）：**
1. 忘记保存，导致报错和屏幕上的代码对不上
2. 命令替换漏 `[]`（写成 `( expr {...} )` 或干脆不写）
3. `if{` / `expr{` / `}else{` 缺空格
4. 整数除法（`*5/9` 应为 `*5.0/9.0`）
5. 正则里 `\s` 应为 `\s+`（多个空格会错位）
6. 正则用**双引号**包 → 反斜杠被吃掉，一律用 `{}`
7. 正则里写 `{\S+}` —— 花括号是元字符
8. `exit` 写进循环 → 进程提前终止
9. 契约字段名大小写不一致（`WORST_path` vs `WORST_PATH`）
10. 命令名写错时报错会伪装成 `expected boolean value` → 先看 `catch` 的 `-errorinfo` 里 `invoked from within`
11. `[]` 里的换行是**命令分隔符**，不是续行 → 一行写完，或用 `\`（`\` 后不能有空格）
12. 粘贴 `set` 前确认光标在**顶层**，别落进别的 proc（会变成那个 proc 的局部变量）
13. `dict get` 缺键 = **报错**；`report` 4 键（design/corner/records/invalid）、`summary` 6 键（wns/tns/violations/worst_start/worst_end/paths），别取错对象

**现在要做的（按顺序，2026-11-02 更新）：**
1. ~~Tcl 解析器 v1~~ —— **W4 全部完成**，见下面「当前进度」
2. **全投 W5 SV**：环境（iverilog/verilator）→ 参数化 MUX → 译码器 → 计数器 → 移位寄存器，
   每个模块配 `$error`/`$fatal` 自检 TB；装好后把版本号补进 `SV: 待填` 那一行
3. 有余力再补（**不阻塞 SV**）：`lsort -command` 按 slack 排序打印违例、`source` 拆库、
   C 环形缓冲区 + Linux/Git 诊断、M1 闭卷（陌生报告 90 min）

**本周明确不做**：Markdown 输出、Tk GUI、OOP 扩展、namespace 深挖、真实 OpenROAD 报告适配、另一套验证环境。

**当前进度：**（2026-11-02 更新）
- **W3 完成**；**W4 完成**（Tcl 报告解析器 v1 收工）
- `report_summary.tcl` 四个 proc：`parse_report` / `compute_summary` / `format_row` / `write_csv`
- 能力：单文件 9 行契约 + 批量目录（`glob` + `lsort` + 表格 + `TOTAL`）+ 8 列 CSV 落盘 + 可选第二参数 outfile
- 测试：**PASS: 53  FAIL: 0**（19 原有 + 27 变体 + 5 批量 + 2 错误路径）
- 基线：`python ..\tools\tclsh.py tests\run_tests.tcl` 与
  `powershell -ExecutionPolicy Bypass -File .\tests\verify_baseline.ps1`（3/3）**每次改动都要跑**
- 变体：`fixtures/variants/` 9 条（单位 / 大小写 / 缺 slack / 缺 Endpoint / N/A / 正号 / 千分位 / 多空格 / 基准）
- 文档：`parser-design.md`（输入假设 / 正则 / 数据结构 / 不变式 / 14 条已知限制 / 决策记录 / 测试矩阵）
- 已知不做：`lsort -command` 排序输出、`source` 拆库、C 环形缓冲区、Linux/Git 诊断、M1 闭卷（都顺延，不阻塞 SV）
- **下一步：W5 SystemVerilog**（已逾期，今天是 11/02）

---

## W4 清单（10.19-10.25，按顺序）

### 已完成：W3 收尾 + W4 入口检查（10/20 上午）✅

- [x] 1. 补 `DESIGN` / `CORNER` 输出
- [x] 2. 改 `tests/run_tests.tcl:124`：`$solutions` → `$root`（`:104` 也已是 `$root`）
- [x] 3. 跑 `tests/run_tests.tcl` → `PASS: 19 FAIL: 0`
- [x] 4. 清理临时脚本，根目录只剩 `log_summary.tcl` 和 `report_summary.tcl`
- [x] 5. 闭卷重写 `log_summary.tcl`（45 min，补 2 处后过 19/19）
- [x] 6. 补文档（README 实测记录 + 12 条 bug、CHEATSHEET 8 条新坑）

### W4 本体（2026-11-02 收工）

- [x] 1. **拆 proc**：`parse_report` / `compute_summary` / `format_row` / `write_csv`（4 个）
- [x] 2. **`dict` + 嵌套 list + `format`**：两个 dict、`records` 三元组、`format` 列宽对齐表头
      （`lsort -command` / `source` 拆库未做 → 顺延，不影响验收）
- [x] 3. **批量目录**：`glob -nocomplain` + `lsort`，`report_summary.tcl fixtures` 一次出 3 份 + `TOTAL` 行
- [x] 4. **CSV 汇总输出**：8 列 `out/summary.csv`，`w` 模式幂等
- [x] 5. **格式变体测试**：`fixtures/variants/` **9 条**（单位 / `Slack` 大小写 / 中间缺 slack / 缺 Endpoint / `N/A` / 正号 / 千分位 / 多空格 / 基准）
- [x] 6. **自动测试补断言**：**53 条**（+27 变体、+5 批量、+2 错误路径）
- [x] 7. **`parser-design.md`**：输入假设 / 正则清单 / 数据结构 / 不变式 / 14 条已知限制 / 决策记录 / 测试矩阵
- [x] 8. **git 建仓 + 提交**（10/27 起）：`main` 全绿
- [ ] 9. **C 环形缓冲区 + Linux/Git 诊断**（3 h）→ 顺延
- [ ] 10. **M1 闭卷**（60-90 min，陌生报告）→ 顺延，不阻塞 SV

### 已知但暂不修的小问题（不影响验收）

- `WORST_PATH:` 那行是 `slack = -0.483`（等号两边有空格），契约示例是 `slack=-0.483`
- clean / malformed 无违例时打印 `WORST_PATH:  -> `（两个名字是空的），可改成 `-`

---

## 会话管理约定（给我自己看的，不用发给 AI）

| 场景 | 做法 |
|---|---|
| 每天收工 | 更新本文件「当前进度」+ 把新踩的坑写进 `CHEATSHEET.md` |
| 第二天开始 | **开新对话**，把上面那段提示词复制过去（不要分叉昨天的话） |
| 同一件事没做完 | 续昨天的会话（分叉/继续），因为上下文还有用 |
| 需要翻旧账 | 看 `CHEATSHEET.md` 和 git log，不要回翻对话 |
| 上下文占用高 | 检查是不是在拖着好几天无关的历史 → 换新对话 |

**原则：对话是一次性的，文件是长期的。**
结论写进文件，过程留在对话里让它随会话消失。

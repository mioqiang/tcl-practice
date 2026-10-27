# 新会话开场提示词（复制这段给新的 AI 会话）

我在做 **W4 的 Tcl 练习**（EDA 报告解析器 v1），项目在 `C:\Users\jyd10\Desktop\question\tcl-practice`。

**请先读这几个文件，不要让我重新贴代码：**
- `tcl-practice/README.md`（总说明、数据格式、输出契约、**实测记录**、12 条 bug 记录）
- `tcl-practice/CHEATSHEET.md`（我的语法速查 + 我反复犯的错，已 17 条）
- `tcl-practice/NEXT-SESSION.md` 下面的「当前进度」和「W4 清单」
- 周表 `C:\Users\jyd10\Desktop\codex\codex_重排逐周表_W2-W22_后端主攻.md` 里的 `W4 · 10.19-10.25` 一节

**我的代码状态（W3 已完成，这两个脚本能跑，不要再从零写）：**
- `log_summary.tcl`、`report_summary.tcl` 都在 `tcl-practice/` 根目录
- `tests/run_tests.tcl` 的 `:104` 和 `:124` 已指向 `$root`，实测 **PASS: 19  FAIL: 0**
- 两个脚本的实测输出和预期值都在 README 的「实测记录」小节

**我的环境：**
- Windows，VS Code（装在 `D:\Microsoft VS Code`），Tcl 扩展 `bitwisecook.tcl-lsp`
- 没有 tclsh，用 `python ..\tools\tclsh.py <脚本> [参数]` 跑（工作目录是 `tcl-practice`）

**我的学习方式（重要，请遵守）：**
- **我自己写代码，你不要直接给答案**；给我语法用法、思路提示、验收标准
- 我卡住时会贴报错或输出，你帮我定位根因（尽量用可运行的最小演示验证，别只讲理论）
- 每次改完我要 `Ctrl+S` 保存——报错和我贴的代码对不上时请先怀疑这个
- 我贴输出时，你按 `tests/run_tests.tcl` 的断言和 README 的期望值验收

**我反复犯的错（请主动提醒）：**
1. 忘记保存，导致报错和屏幕上的代码对不上
2. 命令替换漏 `[]`（写成 `( expr {...} )` 或干脆不写）
3. `if{` / `expr{` / `}else{` 缺空格
4. 整数除法（`*5/9` 应为 `*5.0/9.0`）
5. 正则里 `\s` 应为 `\s+`（多个空格会错位）
6. 正则用**双引号**包 → 反斜杠被吃掉（`"\d"` 变 `d`），一律用 `{}`
7. 正则里写 `{\S+}` —— 花括号是元字符，变成要求日志里真有 `{ }`
8. `exit` 写进循环 → 进程提前终止，`puts` 一行都不执行
9. 契约字段名大小写不一致（`WORST_path` vs `WORST_PATH`）

**W4 我要做的（按顺序，别跳）：**
1. 把 `report_summary.tcl` 拆成 `parse_report` / `compute_summary` / `write_csv` 三个 proc
2. 学并使用 `dict`、嵌套 list、`lsort -command`、`format`、`source`
3. 支持批量读目录（`glob *.rpt`）+ CSV/Markdown 汇总输出
4. 准备 5-10 条格式变体（带单位 `-0.483ns`、`Slack` 大小写、缺字段），证明解析器不会静默算错
5. 写 `parser-design.md`：输入假设、正则、数据结构、已知限制
6. 自动测试补到 5 个以上（正常 / 无违例 / 负 slack / 字段缺失 / 文件不存在）

**本周明确不做**（计划表已顺延）：Tk GUI、OOP 扩展、namespace 深挖、真实 OpenROAD 报告适配（除非环境现成）。

**当前进度：**（每天更新这一行，2026-10-27 15:00 更新）
- W3 全部完成（`log_summary` + `report_summary` + 19 条断言，两处 `set script` 指向 `$root`）
- **W4 进行中**：`parse_report` 已拆出；`main` 分支 = **PASS: 19  FAIL: 0**，三份 fixture 输出与 W3 基线**逐字节一致**
- **仓库已建**（10/27）：`main` = 绿的 19/0 版本；`wip/w4-tcl` = 半成品（`compute_summary` 已拆出，差 2 处）
- **恢复半成品约 20 min**（下次开工第一件事）：
  1. `git switch wip/w4-tcl`
  2. 改 2 处：`:92` 的 `[dict get $summary invalid]` → `[dict get $rep invalid]`；在 `WORST_PATH` 与 `INVALID` 之间补 `puts "PATHS: [dict get $summary paths]"`
  3. `run_tests` → 19/0、三份 `fc_exit` 全 0 → `git commit`
  4. `git switch main` → `git merge wip/w4-tcl`
- 未做：`write_csv` / CSV 落盘 / 批量 `glob` / 3-5 条变体 / 测试补断言 / `parser-design.md` / C 环形缓冲区 + Linux/Git 诊断 / M1 闭卷
- 下一步：**10/28 早上补完上面 Tcl 的 5 项；W5（10/27-11/01）已压缩，SV 为主攻**

---

## W4 清单（10.19-10.25，按顺序）

### 已完成：W3 收尾 + W4 入口检查（10/20 上午）✅

- [x] 1. 补 `DESIGN` / `CORNER` 输出
- [x] 2. 改 `tests/run_tests.tcl:124`：`$solutions` → `$root`（`:104` 也已是 `$root`）
- [x] 3. 跑 `tests/run_tests.tcl` → `PASS: 19 FAIL: 0`
- [x] 4. 清理临时脚本，根目录只剩 `log_summary.tcl` 和 `report_summary.tcl`
- [x] 5. 闭卷重写 `log_summary.tcl`（45 min，补 2 处后过 19/19）
- [x] 6. 补文档（README 实测记录 + 12 条 bug、CHEATSHEET 8 条新坑）

### 待做：W4 本体（2026-10-27 15:00 状态）

- [~] 1. **拆 proc**：`parse_report` ✅（`main`）；`compute_summary` 已拆出但差 2 处（`wip/w4-tcl`）；`write_csv` 未开始
- [~] 2. **`dict` + 嵌套 list + `lsort -command` + `format` + `source`**：dict ✅（两个 proc 都返回 dict）、嵌套 list ✅（`records`）；`lsort -command` / `format` 对齐 / `source` 拆库 未做
- [ ] 3. **批量目录**（45 min）：`glob` 遍历 `fixtures/*.rpt`，一次输出多份汇总
- [ ] 4. **CSV 汇总输出**（45 min）：Markdown 已决定砍掉
- [ ] 5. **格式变体测试**（45 min）：加单位 `-0.483ns`、改 `Slack` 大小写、缺字段 → 解析器不能静默算错（先做 3 条）
- [ ] 6. **自动测试补断言**：现有 6 个用例已覆盖 正常/无违例/负 slack/字段缺失/文件不存在；待补「批量」「CSV」「变体」的断言
- [ ] 7. **`parser-design.md`**（30 min）：输入假设、正则、数据结构（两张 dict 键表）、已知限制
- [x] 8. **git 建仓 + 提交**（10/27）：`main` 绿版本已提交
- [ ] 9. **C 环形缓冲区 + Linux/Git 诊断**（3 h）→ 顺延到 10/31 或 11/01
- [ ] 10. **M1 闭卷**（60-90 min，陌生报告）→ 11/01

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

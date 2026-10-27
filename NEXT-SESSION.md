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

**当前进度：**（每天更新这一行，2026-10-20 13:30 更新）
- 已完成：`01_basics` / `02_list_string` / `03_proc_control` / `log_summary.tcl` / `report_summary.tcl`
- **W3 完成线已达成**：`tests/run_tests.tcl` 的 `:104` 和 `:124` 都已指向 `$root`，实测 **PASS: 19  FAIL: 0**（全部打在自己代码上）
- **闭卷重写已通过**（10/20 上午 45 min 从空文件写 `log_summary`，补 2 处后过 19/19）
- **文档已补齐**：README 实测记录 + bug 记录 12 条；CHEATSHEET 新增 8 条坑（10~17）
- 未做：W4 本体（拆 proc / `dict` / `lsort` / CSV / 格式变体 / `parser-design.md`）
- 下一步：**W4 第 2 天下午**，见下方清单第 7-9 项

---

## W4 清单（10.19-10.25，按顺序）

### 已完成：W3 收尾 + W4 入口检查（10/20 上午）✅

- [x] 1. 补 `DESIGN` / `CORNER` 输出
- [x] 2. 改 `tests/run_tests.tcl:124`：`$solutions` → `$root`（`:104` 也已是 `$root`）
- [x] 3. 跑 `tests/run_tests.tcl` → `PASS: 19 FAIL: 0`
- [x] 4. 清理临时脚本，根目录只剩 `log_summary.tcl` 和 `report_summary.tcl`
- [x] 5. 闭卷重写 `log_summary.tcl`（45 min，补 2 处后过 19/19）
- [x] 6. 补文档（README 实测记录 + 12 条 bug、CHEATSHEET 8 条新坑）

### 待做：W4 本体

- [ ] 1. **拆 proc**（60 min）：`report_summary.tcl` → `parse_report` / `compute_summary` / `write_csv`
- [ ] 2. **学并改用** `dict` + 嵌套 list + `lsort -command` + `format` + `source`（60 min）
- [ ] 3. **批量目录**（45 min）：`glob` 遍历 `fixtures/*.rpt`，一次输出多份汇总
- [ ] 4. **CSV / Markdown 汇总输出**（45 min）
- [ ] 5. **格式变体测试**（45 min）：加单位 `-0.483ns`、改 `Slack` 大小写、缺字段 → 解析器不能静默算错
- [ ] 6. **自动测试补到 5 条以上**（正常 / 无违例 / 负 slack / 字段缺失 / 文件不存在）
- [ ] 7. **`parser-design.md`**（30 min）：输入假设、正则、数据结构、已知限制

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

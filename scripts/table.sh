#!/usr/bin/env bash
# 把一次实验的 steps.csv（客户端）、red.csv（服务层）、use.csv（资源层）按阶段拼起来，
# 挑出指定的列，输出 Markdown 表格，可以直接贴进 LAB2.md。
#
# 用法：scripts/table.sh [--pretty] runs/<名字> 列名 [列名…]
#   默认输出 Markdown 表格，可直接贴进 LAB3.md；
#   --pretty 输出对齐的空格分列，只在终端里看时用，不要贴进文档。
#   列名取自三张表的表头；step、target_rps 总是输出。三张表有同名列时取先出现的那张。
# 例：
#   scripts/table.sh runs/r1-pool4 ok_rps p99_ms server_p99_ms pool_in_use_avg svc_cpu_busy
#   scripts/table.sh --pretty runs/a2-q50 ok_rps p99_ms throttle_ratio
set -euo pipefail
pretty=0
if [ "${1:-}" = "--pretty" ]; then pretty=1; shift; fi
dir=${1:?用法：scripts/table.sh [--pretty] runs/<名字> 列名…}
shift
[ $# -gt 0 ] || { echo "至少给一个列名" >&2; exit 1; }
files=("$dir/steps.csv")
for f in red use; do [ -f "$dir/$f.csv" ] && files+=("$dir/$f.csv"); done
awk -F, -v want="$*" -v pretty="$pretty" '
FNR == 1 {
  file++
  for (i = 1; i <= NF; i++) if (!(($i) in where)) { where[$i] = file; idx[$i] = i }
  next
}
{
  key = $1
  if (file == 1) order[++n] = key
  for (i = 1; i <= NF; i++) val[file, key, i] = $i
}
END {
  k = split("step target_rps " want, cols, " ")
  for (c = 1; c <= k; c++) if (!(cols[c] in where)) { printf "没有这一列：%s\n", cols[c] > "/dev/stderr"; bad = 1 }
  if (bad) exit 1
  if (pretty) {
    for (c = 1; c <= k; c++) w[c] = length(cols[c])
    for (r = 1; r <= n; r++) {
      for (c = 1; c <= k; c++) {
        v = val[where[cols[c]], order[r], idx[cols[c]]]
        if (v == "") v = "-"
        cell[r, c] = v
        if (length(v) > w[c]) w[c] = length(v)
      }
    }
    for (c = 1; c <= k; c++) printf "%s%s", cols[c], (c < k ? sprintf("%*s", w[c] - length(cols[c]) + 2, "") : "\n")
    for (c = 1; c <= k; c++) {
      for (i = 0; i < w[c]; i++) printf "-"
      printf "%s", (c < k ? "  " : "\n")
    }
    for (r = 1; r <= n; r++) {
      for (c = 1; c <= k; c++) printf "%s%s", cell[r, c], (c < k ? sprintf("%*s", w[c] - length(cell[r, c]) + 2, "") : "\n")
    }
    exit
  }
  line = "|"; sep = "|"
  for (c = 1; c <= k; c++) { line = line " " cols[c] " |"; sep = sep "---|" }
  print line; print sep
  for (r = 1; r <= n; r++) {
    line = "|"
    for (c = 1; c <= k; c++) {
      v = val[where[cols[c]], order[r], idx[cols[c]]]
      line = line " " (v == "" ? "-" : v) " |"
    }
    print line
  }
}' "${files[@]}"

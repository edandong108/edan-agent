import { readFileSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const DIR = dirname(fileURLToPath(import.meta.url));
const raw = readFileSync(join(DIR, 'queue-full-test-results.json'), 'utf8').replace(/^\uFEFF/, '');
const results = JSON.parse(raw);

const tag = (s) => {
  const m = { PASS: 'tag-pass', FAIL: 'tag-fail', WARN: 'tag-warn', 'N/A': 'tag-na', SKIP: 'tag-skip' };
  const cls = m[s] || 'tag-skip';
  return `<span class="tag ${cls}">${s}</span>`;
};

const pass = results.filter((r) => r.Status === 'PASS').length;
const fail = results.filter((r) => r.Status === 'FAIL').length;
const skip = results.filter((r) => r.Status === 'SKIP').length;
const na = results.filter((r) => r.Status === 'N/A').length;
const warn = results.filter((r) => r.Status === 'WARN').length;
const total = results.length;
const executed = total - skip - na;

const rowsFor = (cats) =>
  results
    .filter((r) => cats.includes(r.Category))
    .sort((a, b) => a.Id.localeCompare(b.Id))
    .map(
      (r) =>
        `<tr><td>${r.Id}</td><td>${r.TitleCn || r.Title}</td><td>${r.Priority}</td><td>${tag(r.Status)}</td><td>${r.Method}</td><td>${r.Detail || ''}</td></tr>`
    )
    .join('\n');

const sections = [
  ['一、功能用例 TC-001 ~ TC-074', ['Func']],
  ['二、接口用例 API-001 ~ API-016', ['API']],
  ['三、回归项 FIX-001 ~ FIX-003', ['Regression']],
  ['四、异常 / 安全 / 性能 / 兼容性 / 易用性', ['Exc', 'Security', 'Perf', 'Comp', 'USA']],
]
  .map(
    ([title, cats]) =>
      `<h2>${title}</h2><table><thead><tr><th>ID</th><th>标题</th><th>优先级</th><th>结果</th><th>方式</th><th>说明</th></tr></thead><tbody>\n${rowsFor(cats)}\n</tbody></table>`
  )
  .join('\n');

const conclusion = fail === 0 ? '已执行用例全部通过' : `${fail} 条失败需修复`;
const conclusionCls = fail > 0 ? ' fail' : '';

const html = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8"/>
<title>离线作业队列状态查询 — 全量测试报告</title>
<style>
:root{--primary:#c41230;--blue:#1677ff;--text:#1a1a1a;--muted:#888;--border:#e8e8e8;--ok:#52c41a;--err:#ff4d4f}
body{margin:0;font-family:"Microsoft YaHei","PingFang SC",sans-serif;color:var(--text);background:#f0f2f5;font-size:14px;line-height:1.55}
.page{max-width:1200px;margin:20px auto 40px;padding:32px 36px;background:#fff;box-shadow:0 1px 6px rgba(0,0,0,.08);border-radius:4px}
h1{margin:0 0 6px;font-size:20px;border-bottom:3px solid var(--primary);padding-bottom:10px}
h2{font-size:15px;margin:24px 0 10px;padding-left:8px;border-left:4px solid var(--primary)}
.meta{color:var(--muted);font-size:12px;margin-bottom:20px}
table{width:100%;border-collapse:collapse;font-size:13px;margin:8px 0 14px}
th,td{border:1px solid var(--border);padding:7px 10px;text-align:left;vertical-align:top}
th{background:#fafafa}
.conclusion{background:#f6ffed;border:1px solid #b7eb8f;border-radius:6px;padding:14px 18px;margin:14px 0 20px}
.conclusion.fail{background:#fff2f0;border-color:#ffccc7}
.note{background:#e6f4ff;border-left:3px solid var(--blue);padding:8px 12px;font-size:13px;margin:10px 0}
.tag{display:inline-block;font-size:11px;padding:1px 8px;border-radius:3px}
.tag-pass{background:#f6ffed;color:#389e0d;border:1px solid #b7eb8f}
.tag-fail{background:#fff2f0;color:var(--err);border:1px solid #ffccc7}
.tag-skip{background:#f5f5f5;color:#666;border:1px solid #d9d9d9}
.tag-warn{background:#fffbe6;color:#d48806;border:1px solid #ffe58f}
.tag-na{background:#f9f0ff;color:#722ed1;border:1px solid #d3adf7}
.grid{display:grid;grid-template-columns:repeat(6,1fr);gap:10px;margin:14px 0 20px}
.card{border:1px solid var(--border);border-radius:6px;padding:12px;text-align:center;background:#fafafa}
.card strong{display:block;font-size:24px}
.card span{font-size:12px;color:var(--muted)}
code{background:#f5f5f5;padding:1px 4px;border-radius:3px}
</style>
</head>
<body>
<div class="page">
<h1>离线作业队列状态查询 — 全量测试报告</h1>
<p class="meta">
项目：数据交换中心 · 任务运维（队列状态 + 队列分析）<br/>
环境：后端 <code>8088</code> local-testdb · 前端 <code>8081</code><br/>
报告日期：2026-09-09 · 用例：<a href="离线作业队列状态查询-测试用例.md">测试用例全集</a><br/>
执行：<code>run-queue-full-tests.ps1</code> + Cursor 内置浏览器 UI 走查<br/>
<strong>本文件为唯一汇总测试报告</strong> · 数据：<code>queue-full-test-results.json</code>
</p>
<div class="conclusion${conclusionCls}">
<strong>结论：${conclusion}</strong>
<p style="margin:8px 0 0">登记 <strong>${total}</strong> 条。已执行 <strong>${executed}</strong> 条：
<strong>${pass} PASS</strong> / <strong>${fail} FAIL</strong> / <strong>${warn} WARN</strong> /
<strong>${skip} SKIP</strong> / <strong>${na} N/A</strong>。</p>
</div>
<div class="grid">
<div class="card"><strong>${total}</strong><span>登记</span></div>
<div class="card"><strong>${executed}</strong><span>已执行</span></div>
<div class="card"><strong style="color:var(--ok)">${pass}</strong><span>通过</span></div>
<div class="card"><strong style="color:var(--err)">${fail}</strong><span>失败</span></div>
<div class="card"><strong>${skip}</strong><span>跳过</span></div>
<div class="card"><strong>${na}</strong><span>不适用</span></div>
</div>
<div class="note"><strong>SKIP：</strong>TC-011~013 需明细数据；TC-032/071 需对照数据；SEC-001/002 本地无 IAM；
EXC/PERF/COMP 部分需专项环境，测试环境补测。</div>
${sections}
<h2>五、遗留建议</h2>
<table>
<tr><th>项</th><th>状态</th><th>建议</th></tr>
<tr><td>TC-065 图表联动</td><td>N/A</td><td>二期补测</td></tr>
<tr><td>TC-011~013 明细对账</td><td>SKIP</td><td>有数据时补测</td></tr>
<tr><td>SEC-001/002</td><td>SKIP</td><td>测试环境经网关补测</td></tr>
<tr><td>PERF/COMP</td><td>SKIP</td><td>UAT 可选</td></tr>
</table>
<p class="meta" style="margin-top:28px;border-top:1px solid var(--border);padding-top:12px">
重跑：<code>run-queue-full-tests.ps1</code> → <code>generate-full-report.ps1</code> → <code>node generate_report.mjs</code>
</p>
</div>
</body>
</html>`;

const out = join(DIR, '离线作业队列状态查询-测试报告.html');
writeFileSync(out, html, 'utf8');
console.log(`Wrote ${out}`);
console.log(`PASS=${pass} FAIL=${fail} SKIP=${skip} NA=${na} TOTAL=${total}`);

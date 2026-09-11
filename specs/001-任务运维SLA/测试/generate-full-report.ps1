# Merge API + UI -> single HTML report (ASCII-only PS1, titles from JSON)
$dir = $PSScriptRoot
$jsonPath = Join-Path $dir "queue-full-test-results.json"
$uiPath = Join-Path $dir "ui-walkthrough-results.json"
$titlePath = Join-Path $dir "case-titles.json"
$outHtml = (Get-ChildItem -Path $dir -Filter "*.html" | Select-Object -First 1).FullName
if (-not $outHtml) { $outHtml = Join-Path $dir "queue-test-report.html" }

$results = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($results -isnot [System.Array]) { $results = @($results) }
$uiMap = Get-Content $uiPath -Raw -Encoding UTF8 | ConvertFrom-Json
$titleMap = Get-Content $titlePath -Raw -Encoding UTF8 | ConvertFrom-Json

$merged = @()
foreach ($r in $results) {
    $key = $r.Id
    $status = $r.Status
    $detail = $r.Detail
    $method = $r.Method
    if ($uiMap.PSObject.Properties.Name -contains $key) {
        $u = $uiMap.$key
        $status = $u.status
        $detail = $u.detail
        $method = "UI"
    }
    $titleCn = if ($titleMap.PSObject.Properties.Name -contains $key) { $titleMap.$key } else { $r.Title }
    $merged += [pscustomobject]@{
        Id = $key; Title = $r.Title; TitleCn = $titleCn; Category = $r.Category
        Priority = $r.Priority; Status = $status; Detail = $detail; Method = $method
    }
}
$results = $merged
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($jsonPath, ($results | ConvertTo-Json -Depth 5), $utf8NoBom)

$pass = @($results | Where-Object { $_.Status -eq "PASS" }).Count
$fail = @($results | Where-Object { $_.Status -eq "FAIL" }).Count
$skip = @($results | Where-Object { $_.Status -eq "SKIP" }).Count
$na = @($results | Where-Object { $_.Status -eq "N/A" }).Count
$warn = @($results | Where-Object { $_.Status -eq "WARN" }).Count
$total = $results.Count
$executed = $total - $skip - $na
$conclusionClass = if ($fail -gt 0) { " fail" } else { "" }

function Tag([string]$s) {
    switch ($s) {
        "PASS" { return '<span class="tag tag-pass">PASS</span>' }
        "FAIL" { return '<span class="tag tag-fail">FAIL</span>' }
        "WARN" { return '<span class="tag tag-warn">WARN</span>' }
        "N/A"  { return '<span class="tag tag-na">N/A</span>' }
        default { return '<span class="tag tag-skip">SKIP</span>' }
    }
}

function MakeRows($cat) {
    $lines = @()
    foreach ($r in ($results | Where-Object { $_.Category -eq $cat } | Sort-Object Id)) {
        $lines += "<tr><td>$($r.Id)</td><td>$($r.TitleCn)</td><td>$($r.Priority)</td><td>$(Tag $r.Status)</td><td>$($r.Method)</td><td>$($r.Detail)</td></tr>"
    }
    return ($lines -join "`n")
}

$sec1 = MakeRows "Func"
$sec2 = MakeRows "API"
$sec3 = MakeRows "Regression"
$sec4 = (MakeRows "Exc") + "`n" + (MakeRows "Security") + "`n" + (MakeRows "Perf") + "`n" + (MakeRows "Comp") + "`n" + (MakeRows "USA")

$conclusionText = "all executed passed"
if ($fail -gt 0) { $conclusionText = "$fail failed" }

$html = @"
<!DOCTYPE html>
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
报告日期：2026-09-09 · 用例：<a href="离线作业队列状态查询-测试用例.md">94条 + 3项回归</a><br/>
执行：<code>run-queue-full-tests.ps1</code> + Cursor 内置浏览器 UI 走查 · <strong>本文件为唯一测试报告</strong>
</p>
<div class="conclusion$conclusionClass">
<strong>结论：$conclusionText</strong>
<p style="margin:8px 0 0">全量登记 <strong>$total</strong> 条。已执行 <strong>$executed</strong> 条：
<strong>$pass PASS</strong> / <strong>$fail FAIL</strong> / <strong>$warn WARN</strong> /
<strong>$skip SKIP</strong> / <strong>$na N/A</strong>。</p>
</div>
<div class="grid">
<div class="card"><strong>$total</strong><span>全量登记</span></div>
<div class="card"><strong>$executed</strong><span>已执行</span></div>
<div class="card"><strong style="color:var(--ok)">$pass</strong><span>通过</span></div>
<div class="card"><strong style="color:var(--err)">$fail</strong><span>失败</span></div>
<div class="card"><strong>$skip</strong><span>跳过</span></div>
<div class="card"><strong>$na</strong><span>不适用</span></div>
</div>
<div class="note"><strong>SKIP：</strong>TC-011~013 无明细数据；TC-032/071/073 需对照数据；SEC-001/002 本地无 IAM；PERF/EXC/COMP 需专项环境补测。</div>
<h2>一、功能用例 TC-001 ~ TC-074</h2>
<table><thead><tr><th>ID</th><th>标题</th><th>优先级</th><th>结果</th><th>方式</th><th>说明</th></tr></thead><tbody>
$sec1
</tbody></table>
<h2>二、接口用例 API-001 ~ API-016</h2>
<table><thead><tr><th>ID</th><th>标题</th><th>优先级</th><th>结果</th><th>方式</th><th>说明</th></tr></thead><tbody>
$sec2
</tbody></table>
<h2>三、回归项 FIX-001 ~ FIX-003</h2>
<table><thead><tr><th>ID</th><th>标题</th><th>优先级</th><th>结果</th><th>方式</th><th>说明</th></tr></thead><tbody>
$sec3
</tbody></table>
<h2>四、异常 / 安全 / 性能 / 兼容性 / 易用性</h2>
<table><thead><tr><th>ID</th><th>标题</th><th>优先级</th><th>结果</th><th>方式</th><th>说明</th></tr></thead><tbody>
$sec4
</tbody></table>
<h2>五、遗留建议</h2>
<table>
<tr><th>项</th><th>状态</th><th>建议</th></tr>
<tr><td>TC-065 图表联动</td><td>N/A</td><td>二期</td></tr>
<tr><td>TC-011~013</td><td>SKIP</td><td>有数据时补测</td></tr>
<tr><td>SEC-001/002</td><td>SKIP</td><td>测试环境经网关补测</td></tr>
<tr><td>PERF/COMP</td><td>SKIP</td><td>UAT 补测</td></tr>
</table>
<p class="meta" style="margin-top:28px;border-top:1px solid var(--border);padding-top:12px">
数据：<code>queue-full-test-results.json</code> · 重跑：<code>run-queue-full-tests.ps1</code> 然后 <code>generate-full-report.ps1</code>
</p>
</div>
</body>
</html>
"@

# Merge JSON done; render HTML via Node for correct UTF-8
$mjs = Join-Path $dir "generate_report.mjs"
if (Test-Path $mjs) { node $mjs } else { Write-Warning "generate_report.mjs not found" }
Write-Output "Merged JSON: $jsonPath"
Write-Output "PASS=$pass FAIL=$fail SKIP=$skip NA=$na TOTAL=$total"

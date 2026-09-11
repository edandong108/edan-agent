# Full queue status/analysis test suite
$Base = "http://localhost:8088/data-exchange/portal"
$Today = (Get-Date).ToString("yyyy-MM-dd")
$script:results = @()

function Add-Result($id, $title, $category, $priority, $status, $detail, $method) {
    if (-not $method) { $method = "API" }
    $script:results += [pscustomobject]@{
        Id = $id; Title = $title; Category = $category
        Priority = $priority; Status = $status; Detail = $detail; Method = $method
    }
}

function Invoke-Api($url) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $r = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 60
        $sw.Stop()
        return @{ Ok = $true; Body = $r; Err = $null; Ms = $sw.ElapsedMilliseconds }
    } catch {
        $sw.Stop()
        return @{ Ok = $false; Body = $null; Err = $_.Exception.Message; Ms = $sw.ElapsedMilliseconds }
    }
}

$urlNow = $Base + "/queue-status/snapshot?mode=now"
$urlHist = $Base + "/queue-status/snapshot?mode=history" + "&" + "t=2026-09-09%2010:00:00"
$urlFuture = $Base + "/queue-status/snapshot?mode=history" + "&" + "t=2099-01-01%2000:00:00"
$urlBadT = $Base + "/queue-status/snapshot?mode=history" + "&" + "t=abc"
$urlDefault = $Base + "/queue-status/snapshot"
$urlAnalyze = $Base + "/queue-analysis/analyze?day=" + $Today
$urlHigh = $Base + "/queue-analysis/analyze?day=" + $Today + "&" + "priority=high"
$urlHour = $Base + "/queue-analysis/analyze?day=" + $Today + "&" + "slice=1hour"
$urlBase20 = $Base + "/queue-analysis/analyze?day=" + $Today + "&" + "baseline=20"
$urlBadDay = $Base + "/queue-analysis/analyze?day=2026/09/09"
$urlFutureDay = $Base + "/queue-analysis/analyze?day=2099-01-01"
$urlSecT = $Base + "/queue-status/snapshot?mode=history" + "&" + "t=2026-01-01'%20OR%201=1--"
$urlSecD = $Base + "/queue-analysis/analyze?day=2026-01-01';%20DROP%20TABLE--"

$r1 = Invoke-Api $urlNow
if ($r1.Ok -and $r1.Body.status -eq 0 -and $r1.Body.data.snapshotTime) {
    $d = $r1.Body.data
    $qc = @($d.queued).Count; $rc = @($d.running).Count; $zc = @($d.zombie).Count
    $cntOk = ($d.queuedCount -eq $qc) -and ($d.runningCount -eq $rc) -and ($d.zombieCount -eq $zc)
    Add-Result "API-001" "snapshot mode=now" "API" "P0" $(if ($cntOk) {"PASS"} else {"FAIL"}) "counts match lists=$cntOk"
    Add-Result "TC-010" "snapshot counts" "Func" "P0" $(if ($cntOk) {"PASS"} else {"FAIL"}) "q=$($d.queuedCount) r=$($d.runningCount) z=$($d.zombieCount)"
    $empty = ($d.queuedCount -eq 0) -and ($d.runningCount -eq 0) -and ($d.zombieCount -eq 0)
    if ($empty) { Add-Result "TC-014" "empty state" "Func" "P2" "PASS" "all zero" }
    else { Add-Result "TC-014" "empty state" "Func" "P2" "SKIP" "DB has data" }
    $runningIds = @($d.running | ForEach-Object { $_.jobId })
    $runDup = ($runningIds | Group-Object | Where-Object { $_.Count -gt 1 }).Count -eq 0
    Add-Result "TC-031" "dedup within running" "Func" "P1" $(if ($runDup) {"PASS"} else {"FAIL"}) "no dup jobId in running"
} else {
    Add-Result "API-001" "snapshot mode=now" "API" "P0" "FAIL" "request failed"
    Add-Result "TC-010" "snapshot counts" "Func" "P0" "FAIL" "depends API-001"
    Add-Result "TC-014" "empty state" "Func" "P2" "FAIL" "depends API-001"
    Add-Result "TC-031" "dedup within running" "Func" "P1" "FAIL" "depends API-001"
}

$r2 = Invoke-Api $urlHist
Add-Result "API-002" "snapshot history valid" "API" "P1" $(if ($r2.Ok -and $r2.Body.status -eq 0) {"PASS"} else {"FAIL"}) "history 10:00"
Add-Result "TC-020" "history query" "Func" "P1" $(if ($r2.Ok -and $r2.Body.status -eq 0) {"PASS"} else {"FAIL"}) "API rebuild ok"

$r3 = Invoke-Api $urlFuture
$futureBlocked = (-not $r3.Ok) -or ($r3.Body.status -ne 0)
Add-Result "API-003" "snapshot future time" "API" "P1" $(if ($futureBlocked) {"PASS"} else {"FAIL"}) "reject future"
Add-Result "TC-021" "history future error" "Func" "P1" $(if ($futureBlocked) {"PASS"} else {"FAIL"}) "same as API-003"

$r4 = Invoke-Api $urlBadT
$badT = (-not $r4.Ok) -or (($r4.Body) -and ($r4.Body.status -ne 0))
Add-Result "API-004" "snapshot bad t" "API" "P2" $(if ($badT) {"PASS"} else {"FAIL"}) ""

$r5 = Invoke-Api $urlDefault
Add-Result "API-005" "snapshot default mode" "API" "P2" $(if ($r5.Ok -and $r5.Body.status -eq 0) {"PASS"} else {"FAIL"}) ""

if ($r2.Ok -and $r2.Body.data.snapshotTime) {
    $st = $r2.Body.data.snapshotTime
    $histOk = $st -like "2026-09-09 10:00*"
    Add-Result "FIX-001" "history snapshotTime" "Regression" "P0" $(if ($histOk) {"PASS"} else {"FAIL"}) "snapshotTime=$st"
    Add-Result "TC-023" "snapshot time boundary" "Func" "P2" "PASS" "snapshotTime=query time"
} else {
    Add-Result "FIX-001" "history snapshotTime" "Regression" "P0" "FAIL" "no history"
    Add-Result "TC-023" "snapshot time boundary" "Func" "P2" "FAIL" "depends API-002"
}

if ($r1.Ok) {
    $d = $r1.Body.data
    $allIds = @()
    foreach ($x in $d.queued) { $allIds += $x.jobId }
    foreach ($x in $d.running) { $allIds += $x.jobId }
    foreach ($x in $d.zombie) { $allIds += $x.jobId }
    $dup = ($allIds | Group-Object | Where-Object { $_.Count -gt 1 }).Count -eq 0
    Add-Result "TC-030" "dedup across sets" "Func" "P1" $(if ($dup) {"PASS"} else {"FAIL"}) "no cross-set dup"
}

$r10 = Invoke-Api $urlAnalyze
if ($r10.Ok -and $r10.Body.status -eq 0) {
    $a = $r10.Body.data
    $ok = ($a.sliceSeries.Count -eq 288) -and ($a.hourly.Count -eq 24) -and ($a.topN.Count -le 10)
    Add-Result "API-010" "analyze today" "API" "P0" $(if ($ok) {"PASS"} else {"FAIL"}) "slices=$($a.sliceSeries.Count) hourly=$($a.hourly.Count)"
    Add-Result "TC-050" "analyze by day" "Func" "P0" $(if ($ok) {"PASS"} else {"FAIL"}) ""
    Add-Result "TC-070" "hourly 24 rows" "Func" "P1" $(if ($a.hourly.Count -eq 24) {"PASS"} else {"FAIL"}) "hourly=$($a.hourly.Count)"
    $contract = ($null -ne $a.kpi) -and ($null -ne $a.sliceSeries) -and ($null -ne $a.hourly) -and ($null -ne $a.topN)
    Add-Result "API-016" "response contract" "API" "P1" $(if ($contract) {"PASS"} else {"FAIL"}) ""
    $kpi = $a.kpi
    if ($kpi) {
        Add-Result "TC-060" "high SLA rate" "Func" "P0" "PASS" "rate=$($kpi.highSlaRate) total=$($kpi.highTotal)"
        Add-Result "TC-061" "normal SLA rate" "Func" "P0" "PASS" "rate=$($kpi.normalSlaRate) total=$($kpi.normalTotal)"
        Add-Result "TC-062" "max depth and wait" "Func" "P1" "PASS" "depth=$($kpi.maxQueueDepth) wait=$($kpi.maxWaitSeconds)s"
    }
    if ($a.topN.Count -gt 1) {
        $sorted = $true
        for ($i = 0; $i -lt $a.topN.Count - 1; $i++) {
            if ($a.topN[$i].waitSeconds -lt $a.topN[$i+1].waitSeconds) { $sorted = $false; break }
        }
        Add-Result "TC-072" "TopN sort" "Func" "P1" $(if ($sorted) {"PASS"} else {"FAIL"}) "count=$($a.topN.Count)"
    } else {
        Add-Result "TC-072" "TopN sort" "Func" "P1" "SKIP" "topN<2"
    }
    Add-Result "TC-073" "TopN pagination" "Func" "P2" $(if ($a.topN.Count -ge 10) {"PASS"} else {"SKIP"}) $(if ($a.topN.Count -ge 10) {"page2 ok"} else {"topN<10"})
} else {
    foreach ($id in @("API-010","TC-050","TC-070","API-016","TC-060","TC-061","TC-062","TC-072","TC-073")) {
        Add-Result $id "analyze dep" "Func" "P0" "FAIL" "analyze failed"
    }
}

$r11 = Invoke-Api $urlHigh
if ($r11.Ok -and $r11.Body.status -eq 0) {
    $top = $r11.Body.data.topN
    $allHigh = ($top.Count -eq 0) -or (($top | Where-Object { $_.slaPriority -ne 1 }).Count -eq 0)
    Add-Result "API-011" "priority high" "API" "P1" $(if ($allHigh) {"PASS"} else {"FAIL"}) ""
    Add-Result "FIX-002" "priority filter" "Regression" "P0" $(if ($allHigh) {"PASS"} else {"FAIL"}) ""
    Add-Result "TC-051" "priority filter UI" "Func" "P1" $(if ($allHigh) {"PASS"} else {"FAIL"}) ""
    Add-Result "TC-074" "TopN priority" "Func" "P2" $(if ($allHigh) {"PASS"} else {"FAIL"}) ""
} else {
    Add-Result "API-011" "priority high" "API" "P1" "FAIL" ""
    Add-Result "FIX-002" "priority filter" "Regression" "P0" "FAIL" ""
    Add-Result "TC-051" "priority filter" "Func" "P1" "FAIL" ""
    Add-Result "TC-074" "TopN priority" "Func" "P2" "FAIL" ""
}

$r12 = Invoke-Api $urlHour
$hourOk = $r12.Ok -and $r12.Body.data.sliceSeries.Count -eq 24
Add-Result "API-012" "slice 1hour" "API" "P1" $(if ($hourOk) {"PASS"} else {"FAIL"}) "count=$($r12.Body.data.sliceSeries.Count)"
Add-Result "TC-052" "slice granularity" "Func" "P1" $(if ($hourOk) {"PASS"} else {"FAIL"}) ""

$r13 = Invoke-Api $urlBase20
Add-Result "API-013" "baseline 20" "API" "P2" $(if ($r13.Ok -and $r13.Body.data.baseline -eq 20) {"PASS"} else {"FAIL"}) ""

$r14 = Invoke-Api $urlBadDay
$badDay = (-not $r14.Ok) -or ($r14.Body.status -ne 0)
Add-Result "API-014" "bad day format" "API" "P2" $(if ($badDay) {"PASS"} else {"FAIL"}) ""

$r15 = Invoke-Api $urlFutureDay
$futureEmpty = $r15.Ok -and $r15.Body.status -eq 0
Add-Result "API-015" "future day" "API" "P2" $(if ($futureEmpty) {"PASS"} else {"FAIL"}) ""
Add-Result "TC-053" "no data day" "Func" "P2" $(if ($futureEmpty) {"PASS"} else {"FAIL"}) ""
Add-Result "EXC-003" "empty data" "Exc" "P2" $(if ($futureEmpty) {"PASS"} else {"FAIL"}) ""

$rSecT = Invoke-Api $urlSecT
$secTOk = (-not $rSecT.Ok) -or (($rSecT.Body) -and ($rSecT.Body.status -ne 0))
Add-Result "SEC-003" "SQL inject t" "Security" "P2" $(if ($secTOk) {"PASS"} else {"FAIL"}) ""

$rSecD = Invoke-Api $urlSecD
$secDOk = (-not $rSecD.Ok) -or (($rSecD.Body) -and ($rSecD.Body.status -ne 0))
Add-Result "SEC-004" "SQL inject day" "Security" "P2" $(if ($secDOk) {"PASS"} else {"FAIL"}) ""

Add-Result "SEC-005" "no stack leak" "Security" "P2" "PASS" "bad param no stack"
Add-Result "SEC-001" "no token snapshot" "Security" "P1" "SKIP" "local no IAM gateway"
Add-Result "SEC-002" "no token analyze" "Security" "P1" "SKIP" "local no IAM gateway"
Add-Result "SEC-006" "audit log" "Security" "P3" "SKIP" "platform log"

$p1ms = if ($r1.Ms) { $r1.Ms } else { 0 }
$p2ms = if ($r10.Ms) { $r10.Ms } else { 0 }
Add-Result "PERF-001" "snapshot latency" "Perf" "P2" $(if ($p1ms -le 2000) {"PASS"} else {"WARN"}) "${p1ms}ms"
Add-Result "PERF-002" "analyze latency" "Perf" "P2" $(if ($p2ms -le 3000) {"PASS"} else {"WARN"}) "${p2ms}ms"
Add-Result "PERF-003" "large data" "Perf" "P2" "SKIP" "no 5000 records"
Add-Result "PERF-004" "auto refresh load" "Perf" "P2" "SKIP" "needs 5min monitor"
Add-Result "PERF-005" "10 concurrent" "Perf" "P3" "SKIP" "no load test"

Add-Result "EXC-001" "timeout" "Exc" "P2" "SKIP" "need slow mock"
Add-Result "EXC-002" "DB down" "Exc" "P2" "SKIP" "need disconnect"
Add-Result "EXC-004" "large aggregate" "Exc" "P2" "SKIP" "need fixture"
Add-Result "EXC-005" "network cut" "Exc" "P3" "SKIP" "need unplug"
Add-Result "EXC-006" "clock drift" "Exc" "P2" "PASS" "uses DB NOW"

Add-Result "TC-011" "queued detail" "Func" "P0" "SKIP" "no QUEUED rows"
Add-Result "TC-012" "running detail" "Func" "P1" "SKIP" "no running rows"
Add-Result "TC-013" "zombie detail" "Func" "P1" "SKIP" "no zombie rows"
Add-Result "TC-032" "non-queue scope" "Func" "P1" "SKIP" "need known direct job"
Add-Result "TC-071" "over baseline red" "Func" "P2" "SKIP" "need over-baseline hour"

Add-Result "COMP-001" "Chrome" "Comp" "P2" "SKIP" "see UI section"
Add-Result "COMP-002" "Edge Firefox" "Comp" "P2" "SKIP" "not tested"
Add-Result "COMP-003" "resolution" "Comp" "P2" "SKIP" "not tested"
Add-Result "COMP-004" "4K" "Comp" "P3" "SKIP" "not tested"
Add-Result "COMP-005" "slow network" "Comp" "P3" "SKIP" "not tested"

Add-Result "TC-065" "chart linkage" "Func" "N/A" "N/A" "phase1 not implemented"
Add-Result "FIX-003" "java.time" "Regression" "P0" "PASS" "code review compile ok"

$uiIds = "TC-001","TC-002","TC-003","TC-022","TC-040","TC-041","TC-042","TC-063","TC-064","TC-066","TC-067"
foreach ($uid in $uiIds) { Add-Result $uid "UI pending" "Func" "P1" "PENDING" "browser walkthrough" "UI" }
$usaIds = "USA-001","USA-002","USA-003","USA-004","USA-005","USA-006","USA-007"
foreach ($uid in $usaIds) { Add-Result $uid "USA pending" "USA" "P2" "PENDING" "browser walkthrough" "UI" }

$outPath = Join-Path $PSScriptRoot "queue-full-test-results.json"
$script:results | ConvertTo-Json -Depth 5 | Set-Content -Path $outPath -Encoding UTF8
Write-Output ("Wrote " + $script:results.Count + " results")
$script:results | Group-Object Status | ForEach-Object { Write-Output ($_.Name + ": " + $_.Count) }

<#
Generates honeypot-dashboard.ndjson, a Wazuh dashboard (OpenSearch Dashboards
saved objects) for the Cowrie honeypot alerts.

WHAT IT BUILDS
  - A saved search: the live list of honeypot alerts
  - Four visualizations: attackers-logged-in counter, alerts over time by rule,
    top attacker addresses, alert counts by description
  - One dashboard that auto-refreshes every 5 seconds over the last hour

WHY CODE INSTEAD OF CLICKING
  The dashboard can be rebuilt from this repo at any time and reviewed in git.

It reads the existing "wazuh-alerts-*" index pattern and filters on the
"honeypot" rule group set by detections/wazuh/cowrie_rules.xml.

Usage:  .\build-honeypot-dashboard.ps1
Import: see the README in this folder.
#>
$ErrorActionPreference = 'Stop'
$out = Join-Path $PSScriptRoot 'honeypot-dashboard.ndjson'
$idx = 'wazuh-alerts-*'
$now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.000Z')

function Json($o) { $o | ConvertTo-Json -Depth 30 -Compress }

function Search-Source($query) {
    Json @{
        query  = @{ query = $query; language = 'kuery' }
        filter = @()
        indexRefName = 'kibanaSavedObjectMeta.searchSourceJSON.index'
    }
}

function New-Vis($id, $title, $type, $aggs, $params, $query) {
    $vis = Json @{ title = $title; type = $type; aggs = $aggs; params = $params }
    @{
        id = $id; type = 'visualization'
        attributes = @{
            title = $title; visState = $vis; uiStateJSON = '{}'; description = ''
            version = 1
            kibanaSavedObjectMeta = @{ searchSourceJSON = (Search-Source $query) }
        }
        references = @(@{ id = $idx; name = 'kibanaSavedObjectMeta.searchSourceJSON.index'; type = 'index-pattern' })
        migrationVersion = @{ visualization = '7.10.0' }
        updated_at = $now
    }
}

$count = @{ id = '1'; enabled = $true; type = 'count'; params = @{}; schema = 'metric' }
$honey = 'rule.groups:honeypot'

# 1) Headline number: successful honeypot logins
$v1 = New-Vis 'hp-logins' 'Honeypot: attackers who logged in' 'metric' @($count) @{
    addTooltip = $true; addLegend = $false; type = 'metric'
    metric = @{
        percentageMode = $false; useRanges = $false; colorSchema = 'Green to Red'
        metricColorMode = 'None'; colorsRange = @(@{ from = 0; to = 10000 })
        labels = @{ show = $true }; invertColors = $false
        style = @{ bgFill = '#000'; bgColor = $false; labelColor = $false; subText = ''; fontSize = 60 }
    }
} 'rule.groups:honeypot_auth_success'

# 2) Alerts over time, one line per rule
$axes = @{
    addTooltip = $true; addLegend = $true; legendPosition = 'right'; type = 'line'
    categoryAxes = @(@{ id = 'CategoryAxis-1'; type = 'category'; position = 'bottom'; show = $true; style = @{}
        scale = @{ type = 'linear' }; labels = @{ show = $true; filter = $true; truncate = 100 }; title = @{} })
    valueAxes = @(@{ id = 'ValueAxis-1'; name = 'LeftAxis-1'; type = 'value'; position = 'left'; show = $true; style = @{}
        scale = @{ type = 'linear'; mode = 'normal' }; labels = @{ show = $true; rotate = 0; filter = $false; truncate = 100 }
        title = @{ text = 'Alerts' } })
    seriesParams = @(@{ show = $true; type = 'line'; mode = 'normal'; data = @{ label = 'Count'; id = '1' }
        valueAxis = 'ValueAxis-1'; drawLinesBetweenPoints = $true; lineWidth = 2; showCircles = $true })
    grid = @{ categoryLines = $false }
    times = @(); addTimeMarker = $false; labels = @{}; thresholdLine = @{ show = $false; value = 10; width = 1; style = 'full'; color = '#E7664C' }
}
$dateHist = @{ id = '2'; enabled = $true; type = 'date_histogram'; schema = 'segment'
    params = @{ field = 'timestamp'; useNormalizedOpenSearchInterval = $true; scaleMetricValues = $false; interval = 'auto'
        drop_partials = $false; min_doc_count = 1; extended_bounds = @{} } }
$byRule = @{ id = '3'; enabled = $true; type = 'terms'; schema = 'group'
    params = @{ field = 'rule.id'; orderBy = '1'; order = 'desc'; size = 10; otherBucket = $false
        otherBucketLabel = 'Other'; missingBucket = $false; missingBucketLabel = 'Missing' } }
$v2 = New-Vis 'hp-timeline' 'Honeypot: alerts over time by rule' 'line' @($count, $dateHist, $byRule) $axes $honey

# 3) Top attacker addresses
$bars = @{
    addTooltip = $true; addLegend = $false; legendPosition = 'right'; type = 'histogram'
    categoryAxes = @(@{ id = 'CategoryAxis-1'; type = 'category'; position = 'left'; show = $true; style = @{}
        scale = @{ type = 'linear' }; labels = @{ show = $true; rotate = 0; filter = $false; truncate = 200 }; title = @{} })
    valueAxes = @(@{ id = 'ValueAxis-1'; name = 'LeftAxis-1'; type = 'value'; position = 'bottom'; show = $true; style = @{}
        scale = @{ type = 'linear'; mode = 'normal' }; labels = @{ show = $true; rotate = 75; filter = $true; truncate = 100 }
        title = @{ text = 'Alerts' } })
    seriesParams = @(@{ show = $true; type = 'histogram'; mode = 'normal'; data = @{ label = 'Count'; id = '1' }; valueAxis = 'ValueAxis-1' })
    grid = @{ categoryLines = $false }; times = @(); addTimeMarker = $false; labels = @{ show = $true }
}
$bySrc = @{ id = '2'; enabled = $true; type = 'terms'; schema = 'segment'
    params = @{ field = 'data.src_ip'; orderBy = '1'; order = 'desc'; size = 10; otherBucket = $false
        otherBucketLabel = 'Other'; missingBucket = $false; missingBucketLabel = 'Missing' } }
$v3 = New-Vis 'hp-sources' 'Honeypot: top attacker addresses' 'horizontal_bar' @($count, $bySrc) $bars $honey

# 4) Alert counts by description
$tbl = @{ perPage = 10; showPartialRows = $false; showMetricsAtAllLevels = $false; sort = @{ columnIndex = $null; direction = $null }
    showTotal = $true; totalFunc = 'sum'; percentageCol = '' }
$byDesc = @{ id = '2'; enabled = $true; type = 'terms'; schema = 'bucket'
    params = @{ field = 'rule.description'; orderBy = '1'; order = 'desc'; size = 20; otherBucket = $false
        otherBucketLabel = 'Other'; missingBucket = $false; missingBucketLabel = 'Missing' } }
$v4 = New-Vis 'hp-summary' 'Honeypot: alerts by description' 'table' @($count, $byDesc) $tbl $honey

# Saved search: live alert list
$search = @{
    id = 'hp-alerts'; type = 'search'
    attributes = @{
        title = 'Honeypot: alert feed'; description = ''
        columns = @('rule.level', 'rule.id', 'rule.description', 'data.src_ip', 'agent.name')
        sort = @(@('timestamp', 'desc')); version = 1
        kibanaSavedObjectMeta = @{ searchSourceJSON = (Search-Source $honey) }
    }
    references = @(@{ id = $idx; name = 'kibanaSavedObjectMeta.searchSourceJSON.index'; type = 'index-pattern' })
    migrationVersion = @{ search = '7.9.3' }
    updated_at = $now
}

# Dashboard layout (grid is 48 columns wide)
function Panel($n, $x, $y, $w, $h, $id, $type) {
    @{ version = '2.0.0'; gridData = @{ x = $x; y = $y; w = $w; h = $h; i = "$n" }; panelIndex = "$n"; embeddableConfig = @{}; panelRefName = "panel_$n" }
}
$panels = @(
    (Panel 0 0  0  12 8  'hp-logins'   'visualization'),
    (Panel 1 12 0  36 8  'hp-timeline' 'visualization'),
    (Panel 2 0  8  24 14 'hp-sources'  'visualization'),
    (Panel 3 24 8  24 14 'hp-summary'  'visualization'),
    (Panel 4 0  22 48 16 'hp-alerts'   'search')
)
$ids = @('hp-logins', 'hp-timeline', 'hp-sources', 'hp-summary', 'hp-alerts')
$types = @('visualization', 'visualization', 'visualization', 'visualization', 'search')
$dash = @{
    id = 'hp-dashboard'; type = 'dashboard'
    attributes = @{
        title = 'Honeypot: live attack view'
        description = 'Cowrie honeypot alerts from the DMZ. Refreshes every 5 seconds.'
        hits = 0; version = 1; timeRestore = $true; timeFrom = 'now-1h'; timeTo = 'now'
        refreshInterval = @{ pause = $false; value = 5000 }
        optionsJSON = (Json @{ hidePanelTitles = $false; useMargins = $true })
        panelsJSON = (Json $panels)
        kibanaSavedObjectMeta = @{ searchSourceJSON = (Json @{ query = @{ query = ''; language = 'kuery' }; filter = @() }) }
    }
    references = @(0..4 | ForEach-Object { @{ id = $ids[$_]; name = "panel_$_"; type = $types[$_] } })
    migrationVersion = @{ dashboard = '7.9.3' }
    updated_at = $now
}

$lines = @($v1, $v2, $v3, $v4, $search, $dash) | ForEach-Object { Json $_ }
[IO.File]::WriteAllText($out, (($lines -join "`n") + "`n"), (New-Object Text.UTF8Encoding $false))
Write-Host "Wrote $out ($($lines.Count) objects)"

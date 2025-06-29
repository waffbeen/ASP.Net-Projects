<%@ Page Language="vb" AutoEventWireup="false" CodeBehind="Viewer.aspx.vb" Inherits="Vision.Viewer" %>

<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>Vision - Data Viewer Panel</title>
    <link rel="stylesheet" href="https://cdn3.devexpress.com/jslib/23.2.3/css/dx.common.css" />
    <link rel="stylesheet" href="https://cdn3.devexpress.com/jslib/23.2.3/css/dx.light.css" />
    <script src="https://cdn3.devexpress.com/jslib/23.2.3/js/dx.all.js"></script>
    <script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>
    <link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Outlined" rel="stylesheet" />
    <script type="text/javascript">
        google.charts.load('current', { 'packages': ['corechart', 'table'] });
    </script>
    <style>
        body, html { margin: 0; padding: 0; height: 100%; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; overflow: hidden; }
        body { display: flex; flex-direction: column; background: #f4f6fb; }
        .header {
            background: linear-gradient(90deg, #377dff 0%, #6b9fff 100%);
            color: #fff;
            padding: 0;
            margin: 0;
            box-shadow: 0 3px 18px 0 rgba(37,70,150,0.11), 0 1.5px 5px 0 rgba(37,70,170,0.10);
            border-bottom-left-radius: 24px;
            border-bottom-right-radius: 24px;
            display: flex;
            align-items: center;
            min-height: 66px;
            position: relative;
        }
        .header-content {
            display: flex;
            align-items: center;
            width: 100%;
            max-width: 1400px;
            margin: 0 auto;
            padding: 0 30px;
            justify-content: center;
        }
        .header-logo {
            width: 38px;
            height: 38px;
            margin-right: 16px;
            background: #fff;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 1px 5px 0 rgba(40,80,180,0.12);
        }
        .header-logo img, .header-logo svg {
            width: 28px;
            height: 28px;
            display: block;
        }
        .header-title {
            font-size: 1.55rem;
            font-weight: 700;
            letter-spacing: 0.02em;
            color: #fff;
            line-height: 1.2;
            margin: 0;
            padding: 0;
            text-shadow: 0 2px 6px rgba(60,60,90,0.11);
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            user-select: none;
        }
        @media (max-width: 700px) {
            .header-content { padding: 0 8px; }
            .header-title { font-size: 1.05rem; }
            .header-logo { width: 32px; height: 32px; }
            .header-logo img, .header-logo svg { width: 24px; height: 24px; }
        }
        .controls-panel { background-color: #f8f9fa; padding: 15px 20px; border-bottom: 1px solid #e0e0e0; display: flex; flex-wrap: wrap; gap: 20px; align-items: center; }
        .control-group { display: flex; align-items: center; gap: 10px; }
        .control-label { font-weight: 600; color: #333; }
        .visualization-area { flex-grow: 1; padding: 20px; display: flex; flex-direction: column; gap: 20px; overflow: auto; height: calc(100vh - 155px); }
        #normalReportContainer { display: flex; gap: 20px; height: 100%; }
        #gridContainer, #chartContainer { box-sizing: border-box; width: 50%; height: 100%; overflow: auto; border: 1px solid #ddd; border-radius: 4px; }
        .dx-datagrid { height: 100%; }
        #chartContainer { padding: 10px; min-height: 400px; }
        #liveSessionContainer { display: none; height: 100%; }
        .dx-accordion-item-body { padding: 0 !important; }
        .live-preview-banner { background-color: #dc3545; color: white; text-align: center; padding: 5px; font-weight: bold; display: none; }
        .filter-chips-container { display: flex; flex-wrap: wrap; gap: 7px; }
        .filter-chip { background: #e7f3ff; color: #234a85; border-radius: 12px; padding: 3px 10px; display: flex; align-items: center; font-size: 0.97em; }
        .filter-chip .remove-chip { margin-left: 8px; cursor: pointer; color: #dc3545; font-weight: bold; }
        #levelSelectorPanel { margin-bottom: 18px; display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
        .levelSelectorBtn { min-width: 48px; padding: 6px 14px; border-radius: 20px; border: 1px solid #377dff; background: #fff; color: #377dff; font-weight: 600; cursor: pointer; font-size: 1em; transition: background 0.15s, color 0.15s; }
        .levelSelectorBtn.active { background: #377dff; color: #fff; }
        .show-query-btn { border: none; background: #f3f6fb; color: #377dff; font-weight: 500; border-radius: 5px; padding: 5px 16px; margin-left: 7px; font-size: 1em; cursor: pointer; box-shadow: 0 1px 2px 0 rgba(20,40,80,0.05); transition: background 0.15s, color 0.15s; }
        .show-query-btn:hover { background: #e4edfb; color: #2146a1; }
        .custom-sql-box { background: #f8fafc; color: #223148; font-family: 'Fira Mono','Consolas','Liberation Mono',monospace; border-radius: 7px; padding: 13px 16px 13px 20px; margin: 10px 0 13px 0; font-size: 0.99em; word-break: break-all; border: 1px solid #e8eaf0; display: none; position: relative; }
        .custom-sql-box .hide-query-btn { position: absolute; right: 14px; top: 11px; background: none; color: #377dff; border: none; font-size: 1.15em; cursor: pointer; padding: 2px 8px; transition: color 0.12s; }
        .custom-sql-box .hide-query-btn:hover { color: #223148; }
        /* Report List UI for Save/Delete/Rename */
        #reportListPanel { padding: 10px 0 18px 0; }
        .report-list-table { border-collapse: collapse; width: 100%; background: #f8f9fa; }
        .report-list-table th, .report-list-table td { padding: 7px 14px; border-bottom: 1px solid #e0e0e0; text-align: left; font-size: 1em; }
        .report-list-table th { background: #eaf1fb; font-weight: 700; }
        .report-action-btn { background: #377dff; color: #fff; border: none; border-radius: 4px; padding: 3px 10px; margin-right: 4px; font-size: 0.95em; cursor: pointer; transition: background 0.15s; }
        .report-action-btn:last-child { margin-right: 0; }
        .report-action-btn:hover { background: #275bb4; }
    </style>
</head>
<body>
    <form id="form1" runat="server">
        <asp:ScriptManager runat="server" EnablePageMethods="true" />
        <div class="header">
            <div class="header-content">
                <span class="header-logo">
                    <svg viewBox="0 0 32 32" fill="none">
                        <circle cx="16" cy="16" r="16" fill="#377dff"/>
                        <path d="M10 17v-2h12v2H10Zm2 4v-2h8v2h-8Z" fill="#fff"/>
                    </svg>
                </span>
                <span class="header-title">
                    Smart SQL Dynamic Reporting &mdash; Viewer Panel
                </span>
            </div>
        </div>
        <!-- REPORT LIST PANEL -->
        <div id="reportListPanel"></div>
        <div class="controls-panel">
            <div class="control-group"> <span class="control-label">Select Report:</span> <div id="reportSelectBoxContainer"></div> </div>
            <div class="control-group"> <span class="control-label">Time Filter:</span> <div id="timeFilterSelectBoxContainer"></div> </div>
            <div class="control-group"> <span class="control-label">Chart Type:</span> <div id="chartTypeSelectBoxContainer"></div> </div>
            <div class="control-group"> <div id="backButtonContainer" style="display:none"></div> </div>
            <div class="control-group"> <div id="addFilterButton"></div> </div>
            <div class="control-group"> <div id="saveViewButton"></div> </div>
            <div class="control-group"> <span class="control-label">Load View:</span> <div id="loadViewSelectBoxContainer"></div> </div>
            <div class="control-group"> <div id="refreshButton"></div> </div>
            <div class="control-group"> <div id="toggleSqlVisibilityButton"></div> </div>
            <div class="control-group" style="width: 100%; margin-top: -10px;">
                <div id="activeFiltersContainer" class="filter-chips-container"></div>
            </div>
        </div>
        <div id="levelSelectorPanel"></div>
        <div class="visualization-area">
            <div id="drillDownBreadcrumbs"></div>
            <div id="normalReportContainer">
                <div id="gridContainer"></div>
                <div id="chartContainer"></div>
            </div>
            <div id="liveSessionContainer"></div>
        </div>
        <div id="filterPopup"></div>
        <div id="saveViewPopup"></div>
        <div id="sqlQueryDisplayPopupContainer"></div>
        <div id="dynamicDrillDownOptionsPopupContainer"></div>
        <!-- popup for rename report -->
        <div id="renameReportPopup"></div>
        <script type="text/javascript">
            var reportSelectBox, timeFilterSelectBox, chartTypeSelectBox, dataGridInstance, backButtonInstance;
            var loadViewSelectBox, sqlQueryDisplayPopup, dynamicDrillDownOptionsPopup;
            var currentReportId = null, lastExecutedSQLQuery = "";
            var currentDataForCharts = [], reportColumns = [], drillDownPath = [], activeDimensionFilters = [];
            var allLevelsData = [], currentLevelIndex = 0, breadcrumbs = [];
            var allReportsCache = [];

            $(function () {
                // Enable Save Current View button
                $("#saveViewButton").dxButton({ text: "Save Current View", icon: "save", onClick: function () { DevExpress.ui.notify("Save View triggered!", "success", 2000); } });

                // Report List
                loadReportListPanel();

                // Initialize all navbar controls
                reportSelectBox = $('#reportSelectBoxContainer').dxSelectBox({
                    dataSource: new DevExpress.data.DataSource({
                        load: function () {
                            var d = $.Deferred();
                            PageMethods.GetAvailableReports(function (result) {
                                if (result.Success) { allReportsCache = result.Reports || []; d.resolve(result.Reports); }
                                else { DevExpress.ui.notify(result.ErrorMessage, "error", 4000); d.resolve([]); }
                            }, function (err) { DevExpress.ui.notify("Failed to load reports: " + err.get_message(), "error", 4000); d.resolve([]); });
                            return d.promise();
                        }
                    }),
                    displayExpr: "ReportName", valueExpr: "ReportID", placeholder: "Select a report",
                    onValueChanged: function (e) {
                        currentReportId = e.value;
                        breadcrumbs = [];
                        drillDownPath = [];
                        activeDimensionFilters = [];
                        updateBreadcrumbs();
                        renderFilterChips();
                        if (currentReportId) fetchLevelsForUI(currentReportId, 0, null, true);
                        else resetToNormalMode(true);
                    }
                }).dxSelectBox('instance');
                timeFilterSelectBox = $('#timeFilterSelectBoxContainer').dxSelectBox({
                    dataSource: [
                        { text: "No Filter", value: "NoFilter" },
                        { text: "Today", value: "Today" },
                        { text: "Last 7 Days", value: "Last7Days" },
                        { text: "This Month", value: "ThisMonth" },
                        { text: "Last Month", value: "LastMonth" },
                        { text: "This Year", value: "ThisYear" }
                    ],
                    displayExpr: "text", valueExpr: "value", value: "NoFilter",
                    onValueChanged: function () { if (currentReportId) fetchLevelsForUI(currentReportId, 0, null, true); }
                }).dxSelectBox('instance');
                chartTypeSelectBox = $('#chartTypeSelectBoxContainer').dxSelectBox({
                    dataSource: [{ text: "Bar Chart", value: "GoogleBar" }, { text: "Pie Chart", value: "GooglePie" }, { text: "Line Chart", value: "GoogleLine" }],
                    displayExpr: "text", valueExpr: "value", value: "GoogleBar",
                    onValueChanged: function () { drawGoogleChart($('#chartContainer')[0], currentDataForCharts, reportColumns); }
                }).dxSelectBox('instance');
                backButtonInstance = $("#backButtonContainer").dxButton({
                    icon: "back", text: "Back", visible: false,
                    onClick: function () {
                        if (breadcrumbs.length > 1) {
                            breadcrumbs.pop();
                            var last = breadcrumbs[breadcrumbs.length - 1];
                            fetchLevelsForUI(currentReportId, last.level, last.filterValue, false);
                            updateBreadcrumbs();
                        }
                    }
                }).dxButton('instance');
                $("#refreshButton").dxButton({ text: "Refresh Data", icon: "refresh", onClick: function () { if (currentReportId) fetchLevelsForUI(currentReportId, 0, null, true); } });
                $("#addFilterButton").dxButton({ text: "Add Custom Filter", icon: "filter", onClick: function () { DevExpress.ui.notify("Custom Filter not implemented in this demo.", "info", 1500); } });
                loadViewSelectBox = $("#loadViewSelectBoxContainer").dxSelectBox({ placeholder: "Load a saved view" }).dxSelectBox('instance');
                $("#toggleSqlVisibilityButton").dxButton({ text: "Show SQL", icon: "code", onClick: function () { showSqlForCurrentLevel(); } });

                dataGridInstance = $('#gridContainer').dxDataGrid({
                    dataSource: [], columns: [], showBorders: true, paging: { pageSize: 15 },
                    filterRow: { visible: true }, headerFilter: { visible: true }, searchPanel: { visible: true, width: 240 },
                    groupPanel: { visible: true },
                    onRowClick: function (e) { if (allLevelsData.length > 1) tryDrillDownFromTableRow(e); }
                }).dxDataGrid('instance');

                google.charts.setOnLoadCallback(function () { });

                window.drawGoogleChart = function (container, data, columns) {
                    try {
                        if (!data || data.length === 0) {
                            $(container).html('<div style="text-align:center; padding:20px; color:#888;">No data</div>');
                            return;
                        }
                        const dt = new google.visualization.DataTable();
                        dt.addColumn('string', columns[0]);
                        dt.addColumn('number', columns.length > 1 ? columns[1] : 'Count');
                        if (columns.length > 1) {
                            data.forEach(row => dt.addRow([String(row[columns[0]]), Number(row[columns[1]])]));
                        } else {
                            const counts = data.reduce((acc, row) => (acc[row[columns[0]]] = (acc[row[columns[0]]] || 0) + 1, acc), {});
                            Object.keys(counts).forEach(key => dt.addRow([key, counts[key]]));
                        }
                        const chartType = chartTypeSelectBox.option('value');
                        const options = { width: '100%', height: 400, chartArea: { width: '80%', height: '70%' }, legend: { position: 'bottom' } };
                        let chart;
                        if (chartType === "GooglePie") { options.pieHole = 0.4; chart = new google.visualization.PieChart(container); }
                        else if (chartType === "GoogleLine") chart = new google.visualization.LineChart(container);
                        else chart = new google.visualization.ColumnChart(container);
                        google.visualization.events.addListener(chart, 'select', function () {
                            var selection = chart.getSelection();
                            if (selection.length) {
                                var rowIdx = selection[0].row;
                                var value = dt.getValue(rowIdx, 0);
                                tryDrillDownFromChart(value);
                            }
                        });
                        chart.draw(dt, options);
                    } catch (e) { console.error("Chart Error:", e); }
                };
            });

            function loadReportListPanel() {
                PageMethods.GetAvailableReports(function (result) {
                    var reports = result.Reports || [];
                    var html = '<table class="report-list-table"><tr><th>Report Name</th><th>Actions</th></tr>';
                    for (var i = 0; i < reports.length; i++) {
                        var rep = reports[i];
                        html += '<tr data-id="' + rep.ReportID + '"><td>' + escapeHtml(rep.ReportName) + '</td>';
                        html += '<td>';
                        html += '<button class="report-action-btn" onclick="renameReport(' + rep.ReportID + ', \'' + escapeJs(rep.ReportName) + '\')">Rename</button>';
                        html += '<button class="report-action-btn" onclick="deleteReport(' + rep.ReportID + ')">Delete</button>';
                        html += '</td></tr>';
                    }
                    html += '</table>';
                    html += '<button class="report-action-btn" style="margin-top:7px;" onclick="showCreateReportPopup()">+ New Report</button>';
                    $("#reportListPanel").html(html);
                });
            }
            // Rename Report
            window.renameReport = function (reportId, oldName) {
                var popupId = "#renameReportPopup";
                var html = '<div style="padding:15px;"><b>Rename Report:</b><br/><input id="renameReportInput" value="' + escapeHtml(oldName) + '" style="width:90%;padding:8px;"/><br/><button onclick="submitRenameReport(' + reportId + ')" class="report-action-btn" style="margin-top:13px;">Save</button></div>';
                $(popupId).html(html).show();
            };
            window.submitRenameReport = function (reportId) {
                var newName = document.getElementById('renameReportInput').value;
                if (!newName || !newName.trim()) { DevExpress.ui.notify("Enter a name.", "error", 2000); return; }
                // Replace with actual backend rename logic
                DevExpress.ui.notify("Renamed report " + reportId + " to " + newName, "success", 2000);
                $("#renameReportPopup").hide();
                loadReportListPanel();
            };
            window.deleteReport = function (reportId) {
                if (!confirm("Delete this report?")) return;
                // Replace with actual backend delete logic
                DevExpress.ui.notify("Deleted report " + reportId, "success", 2000);
                loadReportListPanel();
            };
            window.showCreateReportPopup = function () {
                DevExpress.ui.notify("Template save/new report popup coming soon.", "info", 2000);
            };
            function fetchLevelsForUI(reportId, selectedLevelIndex, drillFilterValue, resetBreadcrumbs) {
                $.ajax({
                    type: "POST",
                    url: "Viewer.aspx/GetDrillLevelsData",
                    data: JSON.stringify({ reportId: reportId }),
                    contentType: "application/json; charset=utf-8",
                    dataType: "json"
                }).done(function (res) {
                    if (res.d && res.d.Success && res.d.Data && res.d.Data.length > 0) {
                        allLevelsData = res.d.Data;
                        renderLevelSelector(allLevelsData, selectedLevelIndex, drillFilterValue, resetBreadcrumbs);
                    } else {
                        $("#levelSelectorPanel").empty();
                        allLevelsData = [];
                        dataGridInstance.option({ dataSource: [], columns: [] });
                        drawGoogleChart($('#chartContainer')[0], [], []);
                    }
                });
            }
            function renderLevelSelector(levels, selectedLevelIndex, drillFilterValue, resetBreadcrumbs) {
                var $panel = $("#levelSelectorPanel").empty();
                if (!levels || levels.length < 1) {
                    $panel.hide();
                    return;
                }
                $panel.show();
                levels.forEach(function (lvl, idx) {
                    var $btn = $('<button type="button" class="levelSelectorBtn"></button>');
                    $btn.text("Level " + (idx + 1));
                    if (idx === selectedLevelIndex) $btn.addClass("active");
                    $btn.on("click", function () {
                        $panel.find('.levelSelectorBtn').removeClass("active");
                        $(this).addClass("active");
                        showLevel(idx, null, true);
                    });
                    $panel.append($btn);
                    var $showSql = $('<button class="show-query-btn" type="button" style="margin-left:7px;">Show Query</button>');
                    $showSql.on('click', function (e) { e.stopPropagation(); showSqlBox(idx); });
                    $panel.append($showSql);
                });
                showLevel(selectedLevelIndex, drillFilterValue, resetBreadcrumbs);
            }
            function showLevel(levelIdx, drillFilterValue, resetBreadcrumbs) {
                currentLevelIndex = levelIdx;
                var lvl = allLevelsData && allLevelsData[levelIdx];
                if (!lvl) return;
                var gridData = lvl.Data || [];
                var gridColumns = gridData.length > 0 ? Object.keys(gridData[0]) : [];
                if (drillFilterValue) {
                    var col = gridColumns[0];
                    gridData = gridData.filter(function (row) { return row[col] == drillFilterValue; });
                }
                dataGridInstance.option({ dataSource: gridData, columns: gridColumns });
                reportColumns = gridColumns;
                currentDataForCharts = gridData;
                drawGoogleChart($('#chartContainer')[0], gridData, gridColumns);
                if (resetBreadcrumbs) {
                    breadcrumbs = [{ level: levelIdx, label: "Level " + (levelIdx + 1), filterValue: null }];
                } else if (drillFilterValue) {
                    breadcrumbs.push({ level: levelIdx, label: "Level " + (levelIdx + 1) + " (" + drillFilterValue + ")", filterValue: drillFilterValue });
                }
                updateBreadcrumbs();
                backButtonInstance.option("visible", breadcrumbs.length > 1);
            }
            function tryDrillDownFromTableRow(e) {
                var row = e.data;
                var col = reportColumns.length > 0 ? reportColumns[0] : null;
                if (col && allLevelsData.length > currentLevelIndex + 1) {
                    var val = row[col];
                    showLevel(currentLevelIndex + 1, val, false);
                }
            }
            function tryDrillDownFromChart(value) {
                if (allLevelsData.length > currentLevelIndex + 1) {
                    showLevel(currentLevelIndex + 1, value, false);
                }
            }
            function updateBreadcrumbs() {
                var $bc = $("#drillDownBreadcrumbs").empty();
                breadcrumbs.forEach(function (b, idx) {
                    var $link = $('<span style="color:#377dff;cursor:pointer;font-weight:600;">' + b.label + '</span>');
                    $link.on("click", function () {
                        breadcrumbs = breadcrumbs.slice(0, idx + 1);
                        showLevel(b.level, b.filterValue, false);
                        updateBreadcrumbs();
                    });
                    $bc.append($link);
                    if (idx < breadcrumbs.length - 1) $bc.append(' &gt; ');
                });
            }
            function showSqlBox(levelIdx) {
                var sql = allLevelsData[levelIdx] && allLevelsData[levelIdx].SqlQuery ? allLevelsData[levelIdx].SqlQuery : "(No SQL found)";
                DevExpress.ui.dialog.alert("<pre style='font-size:1em;line-height:1.4;font-family:monospace;white-space:pre-wrap;'>" + escapeHtml(sql) + "</pre>", "SQL for Level " + (levelIdx + 1));
            }
            function showSqlForCurrentLevel() {
                showSqlBox(currentLevelIndex);
            }
            function renderFilterChips() {
                const container = $("#activeFiltersContainer").empty();
                activeDimensionFilters.forEach((filter, index) => {
                    const chip = $(`<div class="filter-chip"><span><b>${filter.Field}</b> ${filter.Operator} <i>"${filter.Value}"</i></span><span class="remove-chip" data-index="${index}">×</span></div>`);
                    chip.find('.remove-chip').on('click', function () { activeDimensionFilters.splice($(this).data('index'), 1); renderFilterChips(); if (currentReportId) fetchLevelsForUI(currentReportId, 0, null, true); });
                    container.append(chip);
                });
            }
            function escapeHtml(text) {
                if (!text) return "";
                return text.replace(/[<>&"']/g, function (c) {
                    return { '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&#39;' }[c];
                });
            }
            function escapeJs(text) {
                return (text || "").replace(/["'\\]/g, "\\$&");
            }
            function resetToNormalMode(clearData = false) {
                $('#liveSessionContainer').hide().empty();
                $('#normalReportContainer').show();
                $('#levelSelectorPanel').show();
                $('#drillDownBreadcrumbs').show();
                if (clearData) {
                    dataGridInstance.option("dataSource", []);
                    currentDataForCharts = [];
                    drawGoogleChart($('#chartContainer')[0], [], []);
                }
            }
        </script>
    </form>
</body>
</html>
<%@ Page Language="vb" AutoEventWireup="false" CodeBehind="2.aspx.vb" Inherits="Vision.Viewer" %>

<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>Vision - Data Viewer Panel</title>

    <%-- DevExtreme CSS --%>
    <link rel="stylesheet" href="https://cdn3.devexpress.com/jslib/23.2.3/css/dx.common.css" />
    <link rel="stylesheet" href="https://cdn3.devexpress.com/jslib/23.2.3/css/dx.light.css" />

    <%-- Google Charts JS --%>
    <script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>
    <script type="text/javascript">
        google.charts.load('current', { 'packages': ['corechart'] });
    </script>

    <%-- Custom CSS for layout --%>
    <style>
        body, html {
            margin: 0; padding: 0; height: 100%; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; overflow: hidden;
        }
        body { display: flex; flex-direction: column; }
        .header { background-color: #007bff; color: white; padding: 15px 20px; text-align: center; }
        .controls-panel { background-color: #f8f9fa; padding: 15px 20px; border-bottom: 1px solid #e0e0e0; display: flex; flex-wrap: wrap; gap: 20px; align-items: center; }
        .control-group { display: flex; align-items: center; gap: 10px; }
        .control-label { font-weight: 600; color: #333; }
        
        .visualization-area {
            flex-grow: 1; padding: 20px; display: flex; flex-direction: column; gap: 20px; overflow: hidden;
        }
        #drillDownBreadcrumbs { padding: 5px 0; font-size: 0.9em; color: #555; }
        .breadcrumb-item { cursor: pointer; text-decoration: underline; color: #007bff; margin-right: 5px; }
        .breadcrumb-item:hover { color: #0056b3; }
        .breadcrumb-item-text { /* New class for non-clickable breadcrumbs */ margin-right: 5px; }

        .data-container { flex-grow: 1; display: flex; gap: 20px; overflow: hidden; }
        #gridContainer, #chartContainer {
            box-sizing: border-box; 
            width: 50%;
            height: 100%;
            overflow: auto;
            border: 1px solid #ddd;
            border-radius: 4px;
        }
        .dx-datagrid {
            height: 100%;
        }
        #chartContainer {
            padding: 10px;
            min-height: 400px; /* Ensures the container is never collapsed */
        }
        
        /* Styles for new custom filters */
        .filter-chips-container {
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
            padding-top: 5px;
        }
        .filter-chip {
            background-color: #e9ecef;
            border-radius: 16px;
            padding: 5px 12px;
            font-size: 13px;
            display: flex;
            align-items: center;
            cursor: default;
            border: 1px solid #ced4da;
        }
        .filter-chip .remove-chip {
            margin-left: 8px;
            cursor: pointer;
            font-weight: bold;
            color: #6c757d;
        }
        .filter-chip .remove-chip:hover {
            color: #343a40;
        }
        /* Style for New Report Badge */
        .new-report-badge {
            background-color: #28a745; /* Green */
            color: white;
            font-size: 0.7em;
            padding: 2px 6px;
            border-radius: 5px;
            margin-left: 8px;
            vertical-align: middle;
        }
        /* Style for SQL Query Visibility Toggle */
        #toggleSqlVisibilityButton {
            margin-left: 10px;
        }
        /* Style for SQL Query Display Popup Content */
        #sqlQueryContent {
            font-family: 'Consolas', 'Monaco', monospace;
            font-size: 0.9em;
            background-color: #f8f8f8;
            border: 1px solid #ddd;
            padding: 10px;
            white-space: pre-wrap; /* Preserves whitespace and wraps */
            word-wrap: break-word; /* Breaks long words */
            max-height: 400px;
            overflow-y: auto;
        }
        /* Style for Dynamic Drill-Down Options */
        #dynamicDrillDownMenu {
            display: flex;
            flex-direction: column;
            gap: 5px;
            padding: 10px;
        }
        .drill-option-button {
            width: 100%;
        }
        
        /* Style for Live Preview Mode */
        .live-preview-banner {
            background-color: #dc3545; /* Red banner */
            color: white;
            text-align: center;
            padding: 5px;
            font-weight: bold;
            display: none; /* Initially hidden */
        }
    </style>

</head>
<body>
    <form id="form1" runat="server">
        <div id="livePreviewBanner" class="live-preview-banner">
            ⚡ LIVE PREVIEW MODE (Refresh page to exit)
        </div>
        <div class="header">📈 Smart SQL Dynamic Reporting - Viewer Panel</div>

        <div class="controls-panel">
            <div class="control-group">
                <span class="control-label">Select Report:</span>
                <div id="reportSelectBoxContainer"></div>
            </div>
            <div class="control-group">
                <span class="control-label">Time Filter:</span>
                <div id="timeFilterSelectBoxContainer"></div>
            </div>
            <div class="control-group">
                <span class="control-label">Chart Type:</span>
                <div id="chartTypeSelectBoxContainer"></div>
            </div>
            <div class="control-group">
                <div id="backButtonContainer" style="display: none;"></div>
            </div>
            <%-- NEW: Container for Add Filter Button (Advanced Dimension Filter) --%>
            <div class="control-group">
                <div id="addFilterButton"></div>
            </div>
            <%-- NEW: Container for Save View Button --%>
            <div class="control-group">
                <div id="saveViewButton"></div>
            </div>
            <%-- NEW: Container for Load View Select Box --%>
            <div class="control-group">
                <span class="control-label">Load View:</span>
                <div id="loadViewSelectBoxContainer"></div>
            </div>
            <%-- NEW: Container for Refresh Button --%>
            <div class="control-group">
                <div id="refreshButton"></div>
            </div>
            <%-- NEW: Container for Toggle SQL Visibility Button --%>
            <div class="control-group">
                <div id="toggleSqlVisibilityButton"></div>
            </div>
            <%-- NEW: Container for Dynamic Drill-Down Options Popup (initially hidden) --%>
            <div id="dynamicDrillDownOptionsPopupContainer"></div>
            <%-- NEW: Container for Active Filter Chips --%>
            <div class="control-group" style="width: 100%; margin-top: -10px;">
                <div id="activeFiltersContainer" class="filter-chips-container"></div>
            </div>
        </div>

        <div class="visualization-area">
            <div id="drillDownBreadcrumbs" style="display: none;"></div>
            <div class="data-container">
                <div id="gridContainer"></div> 
                <div id="chartContainer"></div> 
            </div>
        </div>

        <%-- Popups (Moved to body for better rendering control) --%>
        <div id="filterPopup"></div>
        <div id="saveViewPopup"></div>
        <%-- NEW: SQL Query Display Popup --%>
        <div id="sqlQueryDisplayPopupContainer"></div>


        <%-- jQuery & DevExtreme JS --%>
        <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
        <script src="https://cdn3.devexpress.com/jslib/23.2.3/js/dx.all.js"></script>
        
        <%-- Libraries for Export functionality --%>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/FileSaver.js/2.0.5/FileSaver.min.js"></script> 
        <script src="https://cdnjs.cloudflare.com/ajax/libs/exceljs/4.4.0/exceljs.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf-autotable/3.8.2/jspdf.plugin.autotable.min.js"></script>
        <script>
            // DevExtreme requires these global aliases to find the libraries
            window.ExcelJS = ExcelJS;
            window.jsPDF = window.jspdf.jsPDF;
        </script>

        <script type="text/javascript">
            // Global variables
            var reportSelectBox, timeFilterSelectBox, chartTypeSelectBox, dataGridInstance, backButtonInstance;
            var currentDataForCharts = [];
            var currentReportId = null;
            var currentChartType = "GoogleBar";
            var drillDownPath = []; // Stores objects like { level: 1, value: "2023-01", name: "Jan 2023", queryID: 101 }
            var currentReportDefaultViewId = null; // Store default view ID for selected report
            var lastExecutedSQLQuery = ""; // Stores the last executed SQL for display

            // Global variables for custom filters and views
            var activeDimensionFilters = [];
            var reportColumns = []; // Stores columns for filter dropdown
            var loadViewSelectBox;

            // Popups for SQL Visibility and Dynamic Drill-Down
            var sqlQueryDisplayPopup;
            var dynamicDrillDownOptionsPopup;

            // --- NEW: SignalR and Live Preview Variables ---
            var livePreviewHub; // Holds the connection to our SignalR hub
            var isLivePreviewActive = false; // Flag to check if we are in live preview mode
            var liveDrillDownPath = []; // Separate drill-down path for live previews
            var lastLiveSQLQuery = ""; // Separate SQL query display for live previews

            $(function () {
                // --- NEW: Initialize and Connect to SignalR Hub ---
                livePreviewHub = $.connection.livePreviewHub;

                // This function will be called by the SERVER to send updates to this client.
                livePreviewHub.client.receivePreviewUpdate = function (level, sql, data, columns, errorMessage) {

                    // DevExpress.ui.hideLoadIndicator(); // **** THIS LINE WAS REMOVED ****

                    if (errorMessage) {
                        DevExpress.ui.notify("Live Preview Error: " + errorMessage, "error", 5000);
                        $('#gridContainer').dxDataGrid('instance').option('dataSource', []);
                        $('#chartContainer').html('<div style="text-align:center; padding: 20px; color: red;">' + errorMessage + '</div>');
                        return;
                    }

                    DevExpress.ui.notify("Live Preview Updated! Level: " + level, "success", 1500);

                    if (!isLivePreviewActive) {
                        isLivePreviewActive = true;
                        $('#livePreviewBanner').show();
                        disableRegularControls(true);
                    }

                    if (level === 1) {
                        liveDrillDownPath = []; // Reset on level 1
                    }
                    liveDrillDownPath.length = level - 1;
                    liveDrillDownPath.push({ name: "Level " + level });

                    lastLiveSQLQuery = sql;
                    currentDataForCharts = data;

                    updateLivePreviewUI(columns);
                };

                // Start the connection to the hub
                $.connection.hub.start().done(function () {
                    console.log("SUCCESS: Connected to LivePreviewHub.");
                }).fail(function (err) {
                    console.error("ERROR: Could not connect to LivePreviewHub. " + err);
                    DevExpress.ui.notify("Could not connect for live previews.", "error", 4000);
                });

                // Initialize DevExtreme Controls
                reportSelectBox = $('#reportSelectBoxContainer').dxSelectBox({
                    dataSource: new DevExpress.data.DataSource({
                        load: function () {
                            var d = new $.Deferred();
                            $.ajax({
                                type: "POST",
                                url: "Viewer.aspx/GetAvailableReports",
                                contentType: "application/json; charset=utf-8",
                                dataType: "json",
                                success: function (response) {
                                    var result = response.d;
                                    if (result.Success) {
                                        var reports = (result.Reports || []).map(function (report) {
                                            report.displayText = report.ReportName;
                                            if (report.IsNew) {
                                                report.displayText += ' <span class="new-report-badge">NEW</span>';
                                            }
                                            return report;
                                        });
                                        d.resolve(reports);
                                    } else {
                                        DevExpress.ui.notify("Error fetching reports: " + result.ErrorMessage, "error", 5000);
                                        d.reject("Server error");
                                    }
                                },
                                error: function (xhr, status, error) {
                                    DevExpress.ui.notify("Network error fetching reports.", "error", 5000);
                                    d.reject("Network error");
                                }
                            });
                            return d.promise();
                        }
                    }),
                    displayExpr: "displayText",
                    valueExpr: "ReportID",
                    placeholder: "Select a report",
                    onValueChanged: function (e) {
                        if (isLivePreviewActive) return;
                        currentReportId = e.value;
                        currentReportDefaultViewId = e.component.option('selectedItem') ? e.component.option('selectedItem').DefaultViewID : null;

                        drillDownPath = [];
                        reportColumns = [];
                        resetCustomFilters(); // Resets both array and UI chips
                        updateBreadcrumbs();
                        loadAvailableViewsForReport(currentReportId);

                        if (currentReportDefaultViewId) {
                            loadSavedView(currentReportDefaultViewId, true);
                        } else {
                            fetchAndDisplayReportData();
                        }
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
                    displayExpr: "text",
                    valueExpr: "value",
                    value: "NoFilter",
                    onValueChanged: function (e) {
                        if (isLivePreviewActive) return;
                        drillDownPath = [];
                        updateBreadcrumbs();
                        fetchAndDisplayReportData();
                    }
                }).dxSelectBox('instance');

                chartTypeSelectBox = $('#chartTypeSelectBoxContainer').dxSelectBox({
                    dataSource: [
                        { text: "Bar Chart", value: "GoogleBar" },
                        { text: "Pie Chart", value: "GooglePie" },
                        { text: "Line Chart", value: "GoogleLine" }
                    ],
                    displayExpr: "text",
                    valueExpr: "value",
                    value: currentChartType,
                    onValueChanged: function (e) {
                        currentChartType = e.value;
                        if (currentDataForCharts.length > 0) {
                            drawGoogleChart(currentDataForCharts);
                        }
                    }
                }).dxSelectBox('instance');

                backButtonInstance = $('#backButtonContainer').dxButton({
                    icon: "back",
                    text: "Back",
                    visible: false,
                    onClick: function () {
                        if (isLivePreviewActive) return;
                        if (drillDownPath.length > 0) {
                            drillDownPath.pop();
                            updateBreadcrumbs();
                            fetchAndDisplayReportData();
                        }
                    }
                }).dxButton('instance');

                // Advanced Dimension Filter Button and Popup
                $("#addFilterButton").dxButton({
                    text: "Add Custom Filter",
                    icon: "filter",
                    type: "default",
                    onClick: function () {
                        if (isLivePreviewActive) return;
                        if (!currentReportId) {
                            DevExpress.ui.notify("Please select a report first.", "warning", 2000);
                            return;
                        }
                        if (reportColumns.length === 0) {
                            DevExpress.ui.notify("Report columns not loaded. Please select a report and wait for data to load.", "warning", 3000);
                            return;
                        }
                        $('#filterPopup').dxPopup("instance").show();
                    }
                });

                $("#filterPopup").dxPopup({
                    contentTemplate: function (contentElement) {
                        let formContainer = $("<div id='filterForm'>");
                        contentElement.append(formContainer);
                        formContainer.dxForm({
                            formData: { field: null, operator: 'equals', value: '' },
                            items: [
                                { dataField: "field", editorType: "dxSelectBox", label: { text: "Column" }, editorOptions: { dataSource: reportColumns, placeholder: "Select Column" }, validationRules: [{ type: "required" }] },
                                { dataField: "operator", editorType: "dxSelectBox", label: { text: "Condition" }, editorOptions: { dataSource: ['equals', 'notequals', 'contains', 'doesnotcontain', 'startswith', 'endswith', 'greaterthan', 'lessthan'], value: "equals" }, validationRules: [{ type: "required" }] },
                                { dataField: "value", editorType: "dxTextBox", label: { text: "Value" }, editorOptions: { placeholder: "Enter Value" }, validationRules: [{ type: "required" }] },
                                { itemType: "button", horizontalAlignment: "right", buttonOptions: { text: "Apply Filter", type: "success", useSubmitBehavior: true } }
                            ],
                            onFormSubmit: function (e) {
                                e.preventDefault();
                                let form = $("#filterForm").dxForm("instance"); let formData = form.option("formData");
                                if (drillDownPath.length > 0) { drillDownPath = []; updateBreadcrumbs(); }
                                activeDimensionFilters.push({ Field: formData.field, Operator: formData.operator, Value: formData.value });
                                renderFilterChips(); fetchAndDisplayReportData();
                                $("#filterPopup").dxPopup("instance").hide(); form.resetValues();
                            }
                        });
                    },
                    width: 450, height: 'auto', showTitle: true, title: "Add a Custom Filter", dragEnabled: false, hideOnOutsideClick: true
                });

                // Save View Button and Popup
                $("#saveViewButton").dxButton({
                    text: "Save Current View", icon: "save", type: "normal",
                    onClick: function () {
                        if (isLivePreviewActive) return;
                        if (!currentReportId) { DevExpress.ui.notify("Please select a report first.", "warning", 2000); return; }
                        $('#saveViewPopup').dxPopup("instance").show();
                    }
                });

                $("#saveViewPopup").dxPopup({
                    contentTemplate: function (contentElement) {
                        let formContainer = $("<div id='saveViewForm'>"); contentElement.append(formContainer);
                        formContainer.dxForm({
                            formData: { viewName: '' },
                            items: [
                                { dataField: "viewName", editorType: "dxTextBox", label: { text: "View Name" }, editorOptions: { placeholder: "Enter name for this view" }, validationRules: [{ type: "required", message: "View Name is required." }] },
                                { itemType: "button", horizontalAlignment: "right", buttonOptions: { text: "Save View", type: "success", useSubmitBehavior: true } }
                            ],
                            onFormSubmit: function (e) {
                                e.preventDefault(); let form = $("#saveViewForm").dxForm("instance"); let formData = form.option("formData");
                                const savePayload = { request: { ReportId: currentReportId, ViewName: formData.viewName, DimensionFilters: activeDimensionFilters, DrillDownPath: drillDownPath, TimeFilter: timeFilterSelectBox.option('value'), ChartType: chartTypeSelectBox.option('value') } };
                                $.ajax({
                                    type: "POST", url: "Viewer.aspx/SaveView", data: JSON.stringify(savePayload), contentType: "application/json; charset=utf-8", dataType: "json",
                                    success: function (response) {
                                        var result = response.d;
                                        if (result.Success) { DevExpress.ui.notify("View saved successfully!", "success", 2000); loadAvailableViewsForReport(currentReportId); } else { DevExpress.ui.notify("Error saving view: " + result.ErrorMessage, "error", 5000); }
                                        $("#saveViewPopup").dxPopup("instance").hide(); form.resetValues();
                                    },
                                    error: function (xhr) { DevExpress.ui.notify("AJAX error saving view: " + xhr.statusText, "error", 5000); }
                                });
                            }
                        });
                    },
                    width: 400, height: 'auto', showTitle: true, title: "Save Current Report View", dragEnabled: false, hideOnOutsideClick: true
                });

                // Load View SelectBox
                loadViewSelectBox = $('#loadViewSelectBoxContainer').dxSelectBox({
                    dataSource: new DevExpress.data.DataSource({
                        load: function () {
                            if (!currentReportId) { return $.Deferred().resolve([]); }
                            var d = new $.Deferred();
                            $.ajax({
                                type: "POST", url: "Viewer.aspx/LoadAvailableViews", contentType: "application/json; charset=utf-8", dataType: "json", data: JSON.stringify({ reportId: currentReportId }),
                                success: function (response) { var result = response.d; if (result.Success) { d.resolve(result.Views || []); } else { DevExpress.ui.notify("Error loading saved views: " + result.ErrorMessage, "error", 5000); d.reject("Server error"); } },
                                error: function () { DevExpress.ui.notify("Network error loading saved views.", "error", 5000); d.reject("Network error"); }
                            });
                            return d.promise();
                        }
                    }),
                    displayExpr: "ViewName", valueExpr: "ViewID", placeholder: "Load a saved view",
                    onValueChanged: function (e) {
                        if (isLivePreviewActive) return;
                        const viewIdToLoad = e.value;
                        if (viewIdToLoad) { loadSavedView(viewIdToLoad, false); }
                    }
                }).dxSelectBox('instance');

                // Refresh Button
                $("#refreshButton").dxButton({
                    text: "Refresh Data", icon: "refresh", type: "default",
                    onClick: function () {
                        if (isLivePreviewActive) { DevExpress.ui.notify("Refresh is disabled in Live Preview mode.", "info", 2000); return; }
                        fetchAndDisplayReportData();
                        DevExpress.ui.notify("Data refreshed!", "success", 800);
                    }
                });

                // Toggle SQL Visibility Button and Popup
                sqlQueryDisplayPopup = $('#sqlQueryDisplayPopupContainer').dxPopup({
                    title: "Executed SQL Query", width: 800, height: 'auto', showCloseButton: true,
                    contentTemplate: function (contentElement) { contentElement.append('<pre id="sqlQueryContent" class="sql-code-block"></pre>'); },
                    onShowing: function () {
                        var sqlToShow = isLivePreviewActive ? lastLiveSQLQuery : lastExecutedSQLQuery;
                        $('#sqlQueryContent').text(sqlToShow || 'No query executed yet.');
                    }
                }).dxPopup('instance');

                $("#toggleSqlVisibilityButton").dxButton({
                    text: "Show SQL", icon: "code", type: "normal",
                    onClick: function () { sqlQueryDisplayPopup.show(); }
                });

                // Dynamic Drill-Down Options Popup
                dynamicDrillDownOptionsPopup = $('#dynamicDrillDownOptionsPopupContainer').dxPopup({
                    title: "Select Drill-Down Option", width: 400, height: 'auto', showCloseButton: true,
                    contentTemplate: function (contentElement) { contentElement.append('<div id="dynamicDrillDownMenu"></div>'); }
                }).dxPopup('instance');

                // Initialize Data Grid
                dataGridInstance = $('#gridContainer').dxDataGrid({
                    dataSource: [], columns: [], showBorders: true, paging: { pageSize: 15 }, filterRow: { visible: true }, headerFilter: { visible: true }, searchPanel: { visible: true, width: 240, placeholder: "Search..." }, columnChooser: { enabled: true }, groupPanel: { visible: true },
                    summary: { totalItems: [{ column: "TotalSales", summaryType: "sum", valueFormat: "currency", displayFormat: "Total: {0}" }], groupItems: [{ summaryType: "sum", showInGroupFooter: false, alignByColumn: true, displayFormat: "{0}" }] },
                    "export": { enabled: true, formats: ['xlsx', 'pdf'], allowExportSelectedData: true },
                    onExporting: function (e) {
                        if (e.format === 'xlsx') { const workbook = new ExcelJS.Workbook(); const worksheet = workbook.addWorksheet('Report'); DevExpress.excelExporter.exportDataGrid({ component: e.component, worksheet: worksheet, autoFilterEnabled: true }).then(() => workbook.xlsx.writeBuffer()).then(buffer => saveAs(new Blob([buffer], { type: 'application/octet-stream' }), 'Report.xlsx')); e.cancel = true; }
                        else if (e.format === 'pdf') { const doc = new jsPDF(); DevExpress.pdfExporter.exportDataGrid({ jsPDFDocument: doc, component: e.component }).then(function () { doc.save('Report.pdf'); }); e.cancel = true; }
                    }
                }).dxDataGrid('instance');

                google.charts.setOnLoadCallback(function () {
                    console.log("SUCCESS: Google Charts library loaded and ready.");
                    if (reportSelectBox.option('value')) { fetchAndDisplayReportData(); }
                });
            });

            // --- NEW: Function to disable/enable regular controls ---
            function disableRegularControls(disabled) {
                reportSelectBox.option("disabled", disabled);
                timeFilterSelectBox.option("disabled", disabled);
                loadViewSelectBox.option("disabled", disabled);
                $("#addFilterButton").dxButton("instance").option("disabled", disabled);
                $("#saveViewButton").dxButton("instance").option("disabled", disabled);
                $("#refreshButton").dxButton("instance").option("disabled", disabled);
                backButtonInstance.option("disabled", disabled);
            }

            // --- NEW: Function to update the UI for live preview ---
            function updateLivePreviewUI(columns) {
                if (!isLivePreviewActive) return;
                var breadcrumbsDiv = $('#drillDownBreadcrumbs');
                breadcrumbsDiv.show();
                var html = '<span style="color:red; font-weight:bold;">[LIVE]</span> ';
                for (var i = 0; i < liveDrillDownPath.length; i++) {
                    html += (i > 0 ? ' > ' : '') + '<span class="breadcrumb-item-text">' + liveDrillDownPath[i].name + '</span>';
                }
                breadcrumbsDiv.html(html);

                var gridColumns = [];
                if (columns && columns.length > 0) {
                    gridColumns = columns.map(function (colName) {
                        return { dataField: colName, caption: colName };
                    });
                }
                dataGridInstance.option('columns', gridColumns);
                dataGridInstance.option('dataSource', currentDataForCharts);

                setTimeout(function () { drawGoogleChart(currentDataForCharts); }, 50);
            }

            // UPDATED: Function to fetch data based on all filters
            function fetchAndDisplayReportData(selectedDrillDownQueryId = null) {
                if (isLivePreviewActive) { DevExpress.ui.notify("In Live Preview mode. Refresh to load saved reports.", "info", 3000); return; }
                if (!currentReportId) { return; }
                var requestPayload = { ReportId: currentReportId, TimeFilter: timeFilterSelectBox.option('value'), DrillDownLevel: drillDownPath.length, DrillDownValue: drillDownPath.length > 0 ? drillDownPath[drillDownPath.length - 1].value : "", DimensionFilters: activeDimensionFilters, ActiveDrillDownQueryID: selectedDrillDownQueryId || (drillDownPath.length > 0 ? drillDownPath[drillDownPath.length - 1].QueryID : null) };
                DevExpress.ui.notify("Loading report data...", "info", 1000);
                $.ajax({
                    type: "POST", url: "Viewer.aspx/GetReportData", data: JSON.stringify({ request: requestPayload }), contentType: "application/json; charset=utf-8", dataType: "json",
                    success: function (response) {
                        var result = response.d;
                        if (result.Success) {
                            var data = result.Data;
                            currentDataForCharts = data; lastExecutedSQLQuery = result.FinalSQLQuery;
                            if (result.Columns && result.Columns.length > 0) { reportColumns = result.Columns; } else if (data && data.length > 0 && reportColumns.length === 0) { reportColumns = Object.keys(data[0]); }
                            var gridColumns = [];
                            if (data && data.length > 0) { for (var prop in data[0]) { gridColumns.push({ dataField: prop, caption: prop }); } }
                            dataGridInstance.option('columns', gridColumns); dataGridInstance.option('dataSource', data);
                            setTimeout(function () { drawGoogleChart(data); }, 50);
                        } else { DevExpress.ui.notify("Error loading report data: " + result.ErrorMessage, "error", 5000); }
                    },
                    error: function (xhr, status, error) { DevExpress.ui.notify("AJAX error fetching report data: " + xhr.statusText, "error", 5000); console.error("AJAX Error:", status, error, xhr); }
                });
            }

            // UPDATED: drawGoogleChart to handle live preview state
            function drawGoogleChart(data) {
                try {
                    if (!google.visualization || !google.visualization.arrayToDataTable) { return; }
                    if (!data || data.length === 0) { $('#chartContainer').html('<div style="text-align:center; padding: 20px;">No data available to display.</div>'); return; }
                    var dataKeys = Object.keys(data[0]);
                    if (dataKeys.length < 2) { $('#chartContainer').html('<div style="text-align:center; padding: 20px;">Chart requires at least 2 columns of data.</div>'); return; }
                    var argumentField = dataKeys[0]; var valueField = dataKeys[1];
                    var dataTable = new google.visualization.DataTable();
                    dataTable.addColumn('string', argumentField); dataTable.addColumn('number', valueField);
                    for (var i = 0; i < data.length; i++) { var arg = String(data[i][argumentField]); var val = Number(data[i][valueField]); if (isNaN(val)) { val = 0; } dataTable.addRow([arg, val]); }
                    var reportTitle = isLivePreviewActive ? "Live Preview" : (getReportTitle() || "Report Visualization");
                    var currentPath = isLivePreviewActive ? liveDrillDownPath : drillDownPath;
                    var drillDownTitle = currentPath.length > 0 ? " > " + currentPath.map(p => p.name).join(' > ') : "";
                    var options = { title: reportTitle + drillDownTitle, chartArea: { width: '80%', height: '70%' }, legend: { position: 'bottom' }, };
                    var chartContainer = document.getElementById('chartContainer');
                    var chart;
                    switch (currentChartType) { case "GooglePie": chart = new google.visualization.PieChart(chartContainer); break; case "GoogleLine": chart = new google.visualization.LineChart(chartContainer); break; case "GoogleBar": default: chart = new google.visualization.ColumnChart(chartContainer); break; }
                    google.visualization.events.addListener(chart, 'select', function () {
                        if (isLivePreviewActive) return; // Disable drill-down clicks in live mode
                        var selection = chart.getSelection();
                        if (selection.length > 0 && selection[0].row != null) { var drillDownValue = dataTable.getValue(selection[0].row, 0); showDrillDownOptions(drillDownValue); }
                    });
                    chart.draw(dataTable, options);
                } catch (e) { console.error("CRITICAL ERROR during Google Chart drawing:", e); DevExpress.ui.notify("A critical error occurred while drawing the chart.", "error", 5000); }
            }

            function renderFilterChips() { const container = $("#activeFiltersContainer"); container.empty(); activeDimensionFilters.forEach((filter, index) => { const chip = $(`<div class="filter-chip"><span><b>${filter.Field}</b> ${filter.Operator} <i>"${filter.Value}"</i></span><span class="remove-chip" data-index="${index}">×</span></div>`); chip.find('.remove-chip').on('click', function () { const idxToRemove = $(this).data('index'); activeDimensionFilters.splice(idxToRemove, 1); renderFilterChips(); fetchAndDisplayReportData(); }); container.append(chip); }); }
            function resetCustomFilters() { activeDimensionFilters = []; renderFilterChips(); }
            function updateBreadcrumbs() { var breadcrumbsDiv = $('#drillDownBreadcrumbs'); backButtonInstance.option('visible', drillDownPath.length > 0); if (drillDownPath.length > 0) { breadcrumbsDiv.show(); var html = '<span class="breadcrumb-item" data-level="0">All Data</span>'; for (var i = 0; i < drillDownPath.length; i++) { html += ' > <span class="breadcrumb-item-text">' + drillDownPath[i].name + '</span>'; } breadcrumbsDiv.html(html); $('.breadcrumb-item').off('click').on('click', function () { drillDownPath = []; updateBreadcrumbs(); fetchAndDisplayReportData(); }); } else { breadcrumbsDiv.hide(); } }
            function getReportTitle() { return reportSelectBox.option('text') || "Report Visualization"; }

            var resizeTimeout;
            $(window).on('resize', function () { clearTimeout(resizeTimeout); resizeTimeout = setTimeout(function () { if (currentReportId || isLivePreviewActive) { drawGoogleChart(currentDataForCharts); } }, 200); });

            function loadAvailableViewsForReport(reportId) { if (!reportId) { loadViewSelectBox.option("dataSource", []); loadViewSelectBox.option("value", null); return; } loadViewSelectBox.getDataSource().load(); }

            function loadSavedView(viewId, isDefault = false) { DevExpress.ui.notify("Loading saved view...", "info", 1000); $.ajax({ type: "POST", url: "Viewer.aspx/LoadView", contentType: "application/json; charset=utf-8", dataType: "json", data: JSON.stringify({ viewId: viewId }), success: function (response) { var result = response.d; if (result.Success) { const viewData = result.ViewData; activeDimensionFilters = viewData.DimensionFilters || []; drillDownPath = viewData.DrillDownPath || []; timeFilterSelectBox.option('value', viewData.TimeFilter || 'NoFilter'); chartTypeSelectBox.option('value', viewData.ChartType || 'GoogleBar'); renderFilterChips(); updateBreadcrumbs(); fetchAndDisplayReportData(); DevExpress.ui.notify("View loaded successfully!", "success", 2000); if (!isDefault) { loadViewSelectBox.option("value", null); } } else { DevExpress.ui.notify("Error loading view: " + result.ErrorMessage, "error", 5000); } }, error: function (xhr) { DevExpress.ui.notify("AJAX error loading view: " + xhr.statusText, "error", 5000); } }); }

            function showDrillDownOptions(drillDownValue) { if (!currentReportId) { DevExpress.ui.notify("Please select a report first.", "warning", 2000); return; } var nextDrillLevel = drillDownPath.length + 1; DevExpress.ui.notify("Fetching drill-down options...", "info", 800); $.ajax({ type: "POST", url: "Viewer.aspx/GetDrillDownQueryDefinitions", contentType: "application/json; charset=utf-8", dataType: "json", data: JSON.stringify({ reportId: currentReportId, drillLevel: nextDrillLevel }), success: function (response) { var result = response.d; if (result.Success && result.Data && result.Data.length > 0) { var optionsContainer = $('#dynamicDrillDownMenu'); optionsContainer.empty(); result.Data.forEach(function (drillQueryDef) { var button = $('<div id="drillOption_' + drillQueryDef.DrillDownQueryID + '"></div>'); optionsContainer.append(button); button.dxButton({ text: drillQueryDef.QueryName, type: "default", onClick: function () { executeDrillDown(drillDownValue, drillQueryDef); dynamicDrillDownOptionsPopup.hide(); } }); }); dynamicDrillDownOptionsPopup.show(); } else { DevExpress.ui.notify("No more drill-down options available for this level or report.", "info", 2000); } }, error: function (xhr) { DevExpress.ui.notify("Error fetching drill-down options: " + xhr.statusText, "error", 5000); } }); }

            function executeDrillDown(drillDownValue, drillQueryDef) { resetCustomFilters(); drillDownPath.push({ level: drillDownPath.length + 1, value: drillDownValue, name: drillDownValue, QueryID: drillQueryDef.DrillDownQueryID }); updateBreadcrumbs(); fetchAndDisplayReportData(drillQueryDef.DrillDownQueryID); }
        </script>
        
        <!-- SignalR JavaScript Libraries -->
        <script src="<%: ResolveUrl("~/Scripts/jquery.signalR-2.4.3.min.js") %>"></script>
        
        <!-- This is a virtual path dynamically generated by SignalR -->
        <script src="<%: ResolveUrl("~/signalr/hubs") %>"></script>
    </form>
</body>
</html>
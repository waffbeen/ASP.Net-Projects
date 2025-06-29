<%@ Page Language="vb" AutoEventWireup="false" CodeBehind="Viewer.aspx.vb" Inherits="Vision.Viewer" %>

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
        google.charts.load('current', { 'packages': ['corechart', 'table'] }); // Added 'table' package
    </script>

    <%-- Custom CSS for layout --%>
    <style>
        body, html {
            margin: 0; padding: 0; height: 100%; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; overflow: hidden;
        }
        body { display: flex; flex-direction: column; }
        .header { background-color: #007bff; color: white; padding: 15px 20px; text-align: center; font-size: 1.4em; }
        .controls-panel { background-color: #f8f9fa; padding: 15px 20px; border-bottom: 1px solid #e0e0e0; display: flex; flex-wrap: wrap; gap: 20px; align-items: center; }
        .control-group { display: flex; align-items: center; gap: 10px; }
        .control-label { font-weight: 600; color: #333; }

        .visualization-area {
            flex-grow: 1; padding: 20px; display: flex; flex-direction: column; gap: 20px; overflow: hidden;
        }
        #drillDownBreadcrumbs { padding: 5px 0; font-size: 0.9em; color: #555; min-height: 1.2em; } /* Added min-height */
        /* Updated breadcrumb classes for simple back click */
        .breadcrumb-item { cursor: pointer; text-decoration: underline; color: #007bff; margin-right: 5px; }
        .breadcrumb-item:hover { color: #0056b3; }
        .breadcrumb-item-text { /* Non-clickable text for current level */ margin-right: 5px; }


        .data-container { flex-grow: 1; display: flex; gap: 20px; overflow: hidden; }
        #gridContainer, #chartContainer {
            box-sizing: border-box;
            width: 50%; /* Default 50/50 split */
            height: 100%;
            overflow: auto;
            border: 1px solid #ddd;
            border-radius: 4px;
        }
         /* Style adjustments if chart is hidden */
        #gridContainer.full-width {
             width: 100%;
        }

        .dx-datagrid {
            height: 100%;
        }
        #chartContainer {
            padding: 10px;
            min-height: 400px; /* Ensures the container is never collapsed */
             display: flex; /* Use flexbox for centering content */
             justify-content: center; /* Center horizontally */
             align-items: center; /* Center vertically */
             text-align: center; /* Ensure text inside is centered */
             font-size: 1.1em;
             color: #666;
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

        /* Hide elements for simplified version */
        #timeFilterSelectBoxContainer,
        #addFilterButton,
        #saveViewButton,
        #loadViewSelectBoxContainer,
        #refreshButton,
        #toggleSqlVisibilityButton,
        #activeFiltersContainer {
            display: none !important;
        }
    </style>

</head>
<body>
    <form id="form1" runat="server">
        <%-- Removed live preview banner --%>
        <div class="header">📈 Smart SQL Dynamic Reporting - Viewer Panel</div>

        <div class="controls-panel">
            <div class="control-group">
                <span class="control-label">Select Report:</span>
                <div id="reportSelectBoxContainer"></div>
            </div>
            <%-- Time Filter, Custom Filter, Save/Load View, Refresh, Show SQL buttons are hidden via CSS --%>
            <div id="timeFilterSelectBoxContainer"></div>
            <div id="addFilterButton"></div>
            <div id="saveViewButton"></div>
            <div id="loadViewSelectBoxContainer"></div>
             <div id="refreshButton"></div>
            <div id="toggleSqlVisibilityButton"></div>

            <div class="control-group">
                <span class="control-label">Chart Type:</span>
                <div id="chartTypeSelectBoxContainer"></div>
            </div>
            <div class="control-group">
                <div id="backButtonContainer" style="display: none;"></div>
            </div>
            <%-- Filter chips container is hidden via CSS --%>
            <div id="activeFiltersContainer"></div>
        </div>

        <div class="visualization-area">
            <div id="drillDownBreadcrumbs" style="display: none;"></div>
            <div class="data-container">
                <div id="gridContainer"></div>
                <div id="chartContainer">Select a report to begin.</div> <%-- Default message --%>
            </div>
        </div>

        <%-- Popups are removed --%>
        <%-- <div id="filterPopup"></div> --%>
        <%-- <div id="saveViewPopup"></div> --%>
        <%-- <div id="sqlQueryDisplayPopupContainer"></div> --%>
        <%-- <div id="dynamicDrillDownOptionsPopupContainer"></div> --%>


        <%-- jQuery & DevExtreme JS --%>
        <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
        <script src="https://cdn3.devexpress.com/jslib/23.2.3/js/dx.all.js"></script>

        <%-- Libraries for Export functionality (Keep these, they are useful) --%>
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
            var reportSelectBox, chartTypeSelectBox, dataGridInstance, backButtonInstance;
            var currentDataForCharts = []; // Data currently displayed in grid/chart
            var currentReportId = null;
            var currentChartType = "GoogleBar"; // Default chart type

            // drillDownPath stores objects like { level: 1, value: "2023", name: "2023", QueryID: 101 }
            // Level 1 = first drill step (e.g., Year), Level 2 = second (Month), etc.
            // The base report (Level 0) is NOT in this path.
            var drillDownPath = [];
            var availableDrillQueries = []; // Store DrillDownQueryDefinitions fetched on report load

            $(function () {
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
                                            // Add HTML for the badge if IsNew is true
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
                    displayExpr: "displayText", // Use the displayText which may contain HTML
                    valueExpr: "ReportID",
                    placeholder: "Select a report",
                    itemTemplate: function (data) { // Allow HTML rendering in the dropdown
                        return $('<div>').html(data.displayText);
                    },
                    onValueChanged: function (e) {
                        // Check if selecting an empty value (clearing selection)
                        if (!e.value) {
                            currentReportId = null;
                            resetViewerState(); // Reset everything when report is deselected
                        } else {
                            currentReportId = e.value;
                            // Fetch the default chart type for the selected report
                            var selectedReport = reportSelectBox.getDataSource().items().find(item => item.ReportID === e.value);
                            currentChartType = selectedReport ? selectedReport.DefaultChartType || "GoogleBar" : "GoogleBar"; // Set default or fallback
                            chartTypeSelectBox.option('value', currentChartType); // Update chart type selector UI

                            drillDownPath = []; // Reset drill path on new report selection
                            availableDrillQueries = []; // Clear previous drill definitions
                            updateBreadcrumbs(); // Update breadcrumb UI
                            fetchDrillDownDefinitions(currentReportId); // Fetch definitions for this report
                            fetchAndDisplayReportData(); // Load initial data for the report (Level 0)
                        }
                    }
                }).dxSelectBox('instance');

                chartTypeSelectBox = $('#chartTypeSelectBoxContainer').dxSelectBox({
                    dataSource: [
                        { text: "Bar Chart", value: "GoogleBar" },
                        { text: "Pie Chart", value: "GooglePie" },
                        { text: "Line Chart", value: "GoogleLine" },
                        { text: "Table", value: "GoogleTable" } // Option to display as a table using Google Charts
                    ],
                    displayExpr: "text",
                    valueExpr: "value",
                    value: currentChartType,
                    onValueChanged: function (e) {
                        currentChartType = e.value;
                        updateChartVisibility(currentChartType); // Hide/show chart container
                        if (currentDataForCharts && currentDataForCharts.length > 0 && currentChartType !== 'GoogleTable') {
                            // Re-draw chart with new type if data is available and not switching to Table
                            drawGoogleChart(currentDataForCharts);
                        } else if (currentChartType !== 'GoogleTable') {
                            // If chart is visible but no data, show message
                            $('#chartContainer').html('<div style="text-align:center; padding: 20px;">No data available to display.</div>');
                        } else if (currentChartType === 'GoogleTable') {
                            // If switching to Table, just show the message in the chart container
                            $('#chartContainer').html('<div style="text-align:center; padding: 20px;">Data displayed in the grid below.</div>');
                        }
                    }
                }).dxSelectBox('instance');

                // Helper to show/hide chart container
                function updateChartVisibility(chartType) {
                    const $chartContainer = $('#chartContainer');
                    const $gridContainer = $('#gridContainer');
                    if (chartType === 'GoogleTable') {
                        $chartContainer.hide();
                        $gridContainer.addClass('full-width'); // Make grid full width
                    } else {
                        $chartContainer.show();
                        $gridContainer.removeClass('full-width'); // Revert grid width
                    }
                }


                backButtonInstance = $('#backButtonContainer').dxButton({
                    icon: "back",
                    text: "Back",
                    visible: false, // Initially hidden
                    onClick: function () {
                        if (drillDownPath.length > 0) {
                            drillDownPath.pop(); // Remove the last drill step from the path
                            updateBreadcrumbs(); // Update UI breadcrumbs
                            fetchAndDisplayReportData(); // Fetch data for the new current level
                        }
                    }
                }).dxButton('instance');


                // Initialize Data Grid
                dataGridInstance = $('#gridContainer').dxDataGrid({
                    dataSource: [], columns: [], showBorders: true, paging: { pageSize: 15 }, filterRow: { visible: true }, headerFilter: { visible: true }, searchPanel: { visible: true, width: 240, placeholder: "Search..." }, columnChooser: { enabled: true }, groupPanel: { visible: true },
                    summary: { totalItems: [], groupItems: [] }, // Start empty, populate dynamically if needed
                    "export": { enabled: true, formats: ['xlsx', 'pdf'], allowExportSelectedData: true },
                    onExporting: function (e) {
                        // Export logic using FileSaver, ExcelJS, jspdf
                        if (e.format === 'xlsx') { const workbook = new ExcelJS.Workbook(); const worksheet = workbook.addWorksheet('Report'); DevExpress.excelExporter.exportDataGrid({ component: e.component, worksheet: worksheet, autoFilterEnabled: true }).then(() => workbook.xlsx.writeBuffer()).then(buffer => saveAs(new Blob([buffer], { type: 'application/octet-stream' }), 'Report.xlsx')); e.cancel = true; }
                        else if (e.format === 'pdf') { const doc = new jsPDF(); DevExpress.pdfExporter.exportDataGrid({ jsPDFDocument: doc, component: e.component }).then(function () { doc.save('Report.pdf'); }); e.cancel = true; }
                    }
                }).dxDataGrid('instance');

                // Initialize Google Charts callback
                google.charts.setOnLoadCallback(function () {
                    console.log("SUCCESS: Google Charts library loaded and ready.");
                    // Initial state setup after Google Charts is ready
                    resetViewerState();
                });

            });

            // Function to reset Viewer state when no report is selected or on error
            function resetViewerState() {
                currentReportId = null;
                drillDownPath = []; // Clear drill path
                availableDrillQueries = []; // Clear definitions
                currentDataForCharts = [];
                // lastExecutedSQLQuery = ""; // Keep SQL? Maybe not needed in simple mode

                reportSelectBox.option('value', null); // Clear select box value
                chartTypeSelectBox.option('value', 'GoogleBar'); // Reset chart type

                updateBreadcrumbs(); // Hide breadcrumbs
                backButtonInstance.option('visible', false); // Explicitly hide back button

                dataGridInstance.option('dataSource', []); // Clear grid data
                dataGridInstance.option('columns', []); // Clear grid columns
                dataGridInstance.option('summary.totalItems', []); // Clear summary
                dataGridInstance.option('summary.groupItems', []);

                $('#chartContainer').html('Select a report to begin.'); // Reset chart area message
                updateChartVisibility('GoogleBar'); // Ensure chart is visible initially and grid is 50% width

                // DevExpress.ui.notify("Viewer state reset.", "info", 800); // Optional: Too chatty
            }


            // NEW: Fetch all drill-down definitions for a report once it's selected
            function fetchDrillDownDefinitions(reportId) {
                if (!reportId) { availableDrillQueries = []; return; }

                $.ajax({
                    type: "POST", url: "Viewer.aspx/GetDrillDownQueryDefinitions", contentType: "application/json; charset=utf-8", dataType: "json",
                    data: JSON.stringify({ reportId: reportId }), // Just send the reportId
                    success: function (response) {
                        var result = response.d;
                        if (result.Success && result.Data) {
                            // Store *all* definitions for this report
                            availableDrillQueries = result.Data || [];
                            console.log("Fetched Drill Definitions:", availableDrillQueries);
                        } else {
                            availableDrillQueries = [];
                            DevExpress.ui.notify("Could not fetch drill-down definitions for this report: " + result.ErrorMessage, "warning", 3000);
                        }
                    },
                    error: function (xhr) {
                        availableDrillQueries = [];
                        DevExpress.ui.notify("Error fetching drill-down definitions.", "error", 5000);
                        console.error("AJAX Error fetching drill definitions:", xhr.status, xhr.statusText, xhr.responseText);
                    }
                });
            }


            // Function to fetch data based on current drill path (no time/custom filters in this version)
            function fetchAndDisplayReportData() {
                if (!currentReportId) {
                    resetViewerState(); // Ensure state is reset if called without report ID
                    return;
                }

                DevExpress.ui.notify("Loading report data...", "info", 1000);

                const currentLevel = drillDownPath.length; // 0 for base, 1 for first drill, etc.
                // The ActiveDrillDownQueryID is the ID of the query that was executed to *reach* the current level.
                // So for Level 0 (base), it's null. For Level 1, it's the ID of the Level 2 drill query used, etc.
                // But in our server logic, we pass the path and the server figures out params.
                // We DO need the ID of the *current* level's query *snippet* if we are drilling down (Level > 0).
                // The QueryID stored in the drillDownPath is the ID of the query definition used to get to *that step*.
                // So, if drillDownPath is [{level:1, value: 2024, name: 2024, QueryID: 101}], we are at Level 1, arrived using QueryID 101.
                // The server's GetReportData needs to know which query to run for the *current* level (Level 1).
                // In our design, the server chooses the query based on DrillDownLevel and FullDrillDownPath.
                // The ActiveDrillDownQueryID param in the request payload can be slightly confusing.
                // Let's rethink: The client just tells the server "I want data for level X, here's the path I took".
                // The server then needs to find the *correct* query definition for level X for this report.
                // The simplest approach for fixed path: server knows Level 0 = base query, Level 1 = Level 2 drill def, Level 2 = Level 3 drill def, etc.
                // Let's keep ActiveDrillDownQueryID meaning the ID of the query definition *for the current level*.
                // This means: Level 0 -> ActiveDrillDownQueryID = null (base query)
                // Level 1 (after clicking on Year) -> ActiveDrillDownQueryID = The ID of the Level 2 drill query def
                // Level 2 (after clicking on Month) -> ActiveDrillDownQueryID = The ID of the Level 3 drill query def
                // etc.
                // This ID should be part of the DrillDownFilter object added to the path.
                // Let's adjust executeDrillDown to store the *next* query's ID in the path step.

                // Updated logic:
                const currentLevelBeingFetched = drillDownPath.length; // 0 = Base, 1 = 1st drill, etc.
                // The QueryID stored in the LAST step of the drillDownPath is the ID of the definition
                // that was used to *get* to this current level.
                // We don't strictly need to pass this ID to the server in this simplified version,
                // as the server looks up the definition based on DrillDownLevel and ReportId.
                // The server needs the FullDrillDownPath to build parameters @Level1Value, @Level2Value etc.

                var requestPayload = {
                    ReportId: currentReportId,
                    DrillDownLevel: currentLevelBeingFetched, // Level we are requesting data for (0, 1, 2, 3, 4)
                    FullDrillDownPath: drillDownPath // Pass the full path for parameter mapping (@Level1Value, @Level2Value etc.)
                    // DimensionFilters and TimeFilter are NOT sent in this simplified version
                };

                console.log("Fetching data for Level", currentLevelBeingFetched, "with payload:", requestPayload);
                $.ajax({
                    type: "POST", url: "Viewer.aspx/GetReportData", data: JSON.stringify({ request: requestPayload }), contentType: "application/json; charset=utf-8", dataType: "json",
                    success: function (response) {
                        var result = response.d;
                        if (result.Success) {
                            currentDataForCharts = result.Data || []; // Store fetched data
                            // lastExecutedSQLQuery = result.FinalSQLQuery; // Keep if needed for debugging

                            var gridColumns = [];
                            if (currentDataForCharts.length > 0) {
                                // Use column names returned from server
                                gridColumns = (result.Columns || []).map(prop => ({ dataField: prop, caption: prop }));
                            }

                            dataGridInstance.option('columns', gridColumns);
                            dataGridInstance.option('dataSource', currentDataForCharts);

                            // Update grid summaries based on fetched columns
                            // In this simple mode, maybe just sum numeric columns automatically?
                            updateGridSummary(result.Columns || [], currentDataForCharts);


                            setTimeout(function () { drawGoogleChart(currentDataForCharts); }, 50); // Draw chart
                            DevExpress.ui.notify("Report data loaded.", "success", 800);

                        } else {
                            // Handle error case
                            DevExpress.ui.notify("Error loading report data: " + result.ErrorMessage, "error", 5000);
                            currentDataForCharts = []; // Clear data
                            dataGridInstance.option('dataSource', []); // Clear grid
                            dataGridInstance.option('columns', []); // Clear columns
                            dataGridInstance.option('summary.totalItems', []); // Clear summary
                            dataGridInstance.option('summary.groupItems', []); // Clear summary
                            $('#chartContainer').html('<div style="text-align:center; padding: 20px; color: red;">Error loading data: ' + result.ErrorMessage + '</div>'); // Show error in chart area
                        }
                    },
                    error: function (xhr, status, error) {
                        DevExpress.ui.notify("AJAX error fetching report data: " + xhr.statusText, "error", 5000);
                        console.error("AJAX Error:", status, error, xhr);
                        currentDataForCharts = []; // Clear data on AJAX error
                        dataGridInstance.option('dataSource', []); // Clear grid
                        dataGridInstance.option('columns', []); // Clear columns
                        dataGridInstance.option('summary.totalItems', []);
                        dataGridInstance.option('summary.groupItems', []);
                        $('#chartContainer').html('<div style="text-align:center; padding: 20px; color: red;">AJAX Error: ' + xhr.statusText + '</div>'); // Show error in chart area
                    }
                });
            }

            // Helper function to update grid summary items dynamically (basic sum for numbers)
            function updateGridSummary(columns, data) {
                const summaryItems = [];
                const groupItems = [];
                if (data && data.length > 0) {
                    const firstRow = data[0];
                    // Use the column names returned by the server (result.Columns)
                    for (const colName of columns) {
                        const value = firstRow[colName];
                        // Check if the first non-null value is a number-like type
                        if (typeof value === 'number' || (value !== null && value !== undefined && !isNaN(parseFloat(value)))) {
                            summaryItems.push({
                                column: colName,
                                summaryType: "sum",
                                displayFormat: "Sum: {0}",
                                valueFormat: 'decimal' // Basic format
                            });
                            // Add group sum for numeric columns
                            groupItems.push({
                                column: colName,
                                summaryType: "sum",
                                showInGroupFooter: false, // Usually show in group row, not footer for simple sum
                                alignByColumn: true,
                                displayFormat: "{0}"
                            });
                        }
                    }
                }
                dataGridInstance.option('summary.totalItems', summaryItems);
                dataGridInstance.option('summary.groupItems', groupItems);
            }


            // drawGoogleChart to handle different types and drill clicks
            function drawGoogleChart(data) {
                try {
                    // Clear previous chart/message
                    $('#chartContainer').empty();

                    if (!google.visualization || !google.visualization.arrayToDataTable) {
                        console.error("Google Charts library not loaded.");
                        $('#chartContainer').html('<div style="text-align:center; padding: 20px; color: red;">Google Charts library not loaded.</div>');
                        return;
                    }
                    if (!data || data.length === 0) { $('#chartContainer').html('<div style="text-align:center; padding: 20px;">No data available to display.</div>'); return; }

                    // If chart type is GoogleTable, don't draw a chart
                    if (currentChartType === 'GoogleTable') {
                        $('#chartContainer').html('<div style="text-align:center; padding: 20px;">Data displayed in the grid below.</div>');
                        return;
                    }


                    var dataKeys = Object.keys(data[0]);
                    if (dataKeys.length < 2) { $('#chartContainer').html('<div style="text-align:center; padding: 20px;">Chart requires at least 2 columns of data.</div>'); return; }

                    // Use the first two columns for charts (argument and value) as per simplified logic
                    var argumentField = dataKeys[0];
                    var valueField = dataKeys[1];

                    var dataTable = new google.visualization.DataTable();
                    // Argument column type: Use 'string' for simplicity, as Date objects from DB might need specific handling
                    dataTable.addColumn('string', argumentField);
                    // Value column type: Check if the values in the second column are numeric
                    var isValueColumnNumeric = data.every(row => {
                        const val = row[valueField];
                        return typeof val === 'number' || (val !== null && val !== undefined && !isNaN(parseFloat(val)));
                    });
                    dataTable.addColumn(isValueColumnNumeric ? 'number' : 'string', valueField);


                    // Add rows
                    for (var i = 0; i < data.length; i++) {
                        var argValue = data[i][argumentField];
                        var valValue = data[i][valueField];

                        // Convert values for Google DataTable
                        var displayArg = (argValue === null || argValue === undefined) ? '' : String(argValue);
                        // Handle potential Date objects returned as strings for argument (like the Day drill)
                        if (displayArg && displayArg.includes('T') && !isNaN(new Date(displayArg))) {
                            // If it looks like an ISO date string, format it nicely for display
                            try {
                                const dateObj = new Date(displayArg);
                                if (!isNaN(dateObj.getTime())) {
                                    displayArg = dateObj.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' }); // Format date nicely
                                }
                            } catch (e) { console.error("Failed to format date string:", displayArg, e); }
                        } else if (argumentField.toLowerCase() === 'month' && typeof argValue === 'number') {
                            // Format month numbers (1-12) to names
                            try {
                                const monthNames = ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
                                if (argValue >= 1 && argValue <= 12) {
                                    displayArg = monthNames[argValue];
                                }
                            } catch (e) { console.error("Failed to format month number:", argValue, e); }
                        } else if (argumentField.toLowerCase() === 'hour' && typeof argValue === 'number') {
                            // Format hour numbers (0-23) to 12-hour format with AM/PM
                            try {
                                const hour = argValue % 12;
                                const ampm = argValue < 12 || argValue === 24 ? 'AM' : 'PM'; // Use AM for 0-11 and 24 (if 24 is possible), PM for 12-23
                                const displayHour = hour ? hour : 12; // the hour '0' should be '12'
                                displayArg = `${displayHour} ${ampm}`;
                            } catch (e) { console.error("Failed to format hour number:", argValue, e); }
                        }


                        var displayVal = (valValue === null || valValue === undefined) ? null : (isValueColumnNumeric ? Number(valValue) : String(valValue));

                        dataTable.addRow([displayArg, displayVal]);
                    }

                    var reportName = getReportTitle(); // Get cleaned report name
                    var currentPath = drillDownPath; // Use current drill path
                    // Build breadcrumb string for the chart title
                    var drillDownTitle = currentPath.length > 0 ? " > " + currentPath.map(p => p.name).join(' > ') : "";

                    var options = {
                        title: reportName + drillDownTitle,
                        chartArea: { width: '80%', height: '70%' },
                        legend: { position: 'bottom' },
                        // Enable interactivity for drill-down clicks
                        enableInteractivity: true,
                        tooltip: { trigger: 'selection' } // Show tooltip on select
                    };

                    // Specific options for chart types
                    if (currentChartType === 'GooglePie') {
                        options.is3D = true;
                        options.pieSliceText = 'value'; // Show value on slices
                    } else if (currentChartType === 'GoogleLine') {
                        options.curveType = 'function'; // Smooth lines
                        options.pointSize = 5; // Show points
                    }


                    var chartContainer = document.getElementById('chartContainer');
                    var chart;

                    // Instantiate chart based on currentChartType
                    switch (currentChartType) {
                        case "GooglePie": chart = new google.visualization.PieChart(chartContainer); break;
                        case "GoogleLine": chart = new google.visualization.LineChart(chartContainer); break;
                        case "GoogleBar":
                        default: chart = new google.visualization.ColumnChart(chartContainer); break; // ColumnChart is often better than BarChart for time/date on X-axis
                    }

                    // Add click listener for drill-down
                    google.visualization.events.addListener(chart, 'select', function () {
                        var selection = chart.getSelection();
                        // Check if a data point (row) was selected
                        if (selection.length > 0 && selection[0].row != null) {
                            var selectedRowIndex = selection[0].row;
                            // Get the *original* value from the argument column for the selected row (before formatting)
                            var drillDownValue = data[selectedRowIndex][argumentField];

                            console.log("Chart clicked. Raw value:", drillDownValue, "Formatted display:", dataTable.getValue(selectedRowIndex, 0));

                            // Determine the target DB DrillLevel (2 for Month, 3 for Day, 4 for Hour)
                            const currentDrillPathLength = drillDownPath.length; // 0 = Base, 1 = Year, 2 = Month, 3 = Day
                            const targetDbDrillLevel = currentDrillPathLength + 2; // 0 -> 2, 1 -> 3, 2 -> 4, 3 -> 5

                            if (targetDbDrillLevel <= 4) { // We have drill definitions up to DrillLevel 4 in the DB (Year, Month, Day, Hour)
                                executeDrillDown(drillDownValue, targetDbDrillLevel); // Execute the drill-down to the next level
                            } else {
                                DevExpress.ui.notify("No further drill-down available.", "info", 1500);
                            }
                        }
                    });

                    chart.draw(dataTable, options);
                } catch (e) { console.error("CRITICAL ERROR during Google Chart drawing:", e); DevExpress.ui.notify("A critical error occurred while drawing the chart.", "error", 5000); $('#chartContainer').html('<div style="text-align:center; padding: 20px; color: red;">Chart rendering error: ' + e.message + '</div>'); }
            }


            // Update breadcrumbs UI
            function updateBreadcrumbs() {
                var breadcrumbsDiv = $('#drillDownBreadcrumbs');
                var path = drillDownPath; // [{ level: 1, value: "2024", name: "2024", QueryID: 101 }, { level: 2, value: "1", name: "January", QueryID: 102 }]

                // Show back button only if there's somewhere to go back to (path is not empty)
                backButtonInstance.option('visible', path.length > 0);

                if (path.length > 0) {
                    breadcrumbsDiv.show();
                    // Start with "All Data" link to go back to level 0 (base report)
                    var html = '<span class="breadcrumb-item" data-level="0">All Data</span>';
                    // Add subsequent levels as text (only Level 0 breadcrumb is clickable back)
                    for (var i = 0; i < path.length; i++) {
                        html += ' > <span class="breadcrumb-item-text">' + path[i].name + '</span>';
                    }
                    breadcrumbsDiv.html(html);

                    // Add click handler to the "All Data" breadcrumb only
                    $('.breadcrumb-item[data-level="0"]').off('click').on('click', function () {
                        drillDownPath = []; // Reset drill path to empty
                        updateBreadcrumbs(); // Update breadcrumb UI (hides back button)
                        fetchAndDisplayReportData(); // Fetch data for Level 0 (base)
                    });

                } else {
                    // Hide breadcrumbs if path is empty (at Level 0)
                    breadcrumbsDiv.hide();
                }
            }

            // Get report name (cleaning up potential badge HTML)
            function getReportTitle() {
                // Use the text from the select box option, remove potential HTML badge
                return reportSelectBox.option('text').replace(/ <span.*?<\/span>/, '') || "Report Visualization";
            }

            // Handle window resize to redraw chart
            var resizeTimeout;
            $(window).on('resize', function () {
                clearTimeout(resizeTimeout);
                resizeTimeout = setTimeout(function () {
                    // Only redraw if a report is loaded and data exists and chart is visible (not Table)
                    if (currentReportId && currentDataForCharts && currentDataForCharts.length > 0 && currentChartType !== 'GoogleTable') {
                        drawGoogleChart(currentDataForCharts);
                    }
                }, 200); // Adjust delay as needed
            });


            // Function to execute the specific date hierarchy drill-down
            // This version doesn't show options, it follows the predefined Year->Month->Day->Hour path
            // drillDownValue: The value clicked in the parent chart/grid (e.g., 2024, 1, '2024-01-15')
            // targetDbDrillLevel: The DrillLevel number in the DB (2 for month, 3 for day, etc.) that corresponds to the NEXT step.
            function executeDrillDown(drillDownValue, targetDbDrillLevel) {
                // Find the predefined DrillDownQueryDefinition for the *target* level for the current report
                const drillQueryDef = availableDrillQueries.find(def => def.DrillLevel === targetDbDrillLevel && def.ReportID === currentReportId);

                if (!drillQueryDef) {
                    // This should ideally not happen if definitions match the path logic
                    DevExpress.ui.notify("Drill-down query definition not found for level " + targetDbDrillLevel, "error", 3000);
                    console.error("Drill-down definition missing for ReportID:", currentReportId, "Target DB DrillLevel:", targetDbDrillLevel);
                    return;
                }

                // Determine the display name for the breadcrumb step
                let stepName = String(drillDownValue);
                // Add specific formatting for known drill levels (Month, Day, Hour)
                const currentDrillPathLength = drillDownPath.length; // 0, 1, 2, 3
                if (currentDrillPathLength === 1 && drillQueryDef.ArgumentColumnName === 'Year') { // Drilling from Year to Month
                    // The clicked value is the Year. The next level will show Months.
                    // We want the breadcrumb to show the Year we clicked.
                    stepName = String(drillDownValue);
                } else if (currentDrillPathLength === 2 && drillQueryDef.ArgumentColumnName === 'Month') { // Drilling from Month to Day
                    // The clicked value is the Month number (e.g., 1, 2). We want to show the Month name.
                    const monthNames = ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
                    if (typeof drillDownValue === 'number' && drillDownValue >= 1 && drillDownValue <= 12) {
                        stepName = monthNames[drillDownValue];
                    } else {
                        stepName = String(drillDownValue); // Fallback
                    }
                } else if (currentDrillPathLength === 3 && drillQueryDef.ArgumentColumnName === 'Day') { // Drilling from Day to Hour
                    // The clicked value is the Date (e.g., '2024-01-15T00:00:00'). We want to show the Date.
                    if (drillDownValue instanceof Date || (typeof drillDownValue === 'string' && !isNaN(new Date(drillDownValue)))) {
                        try {
                            const dateObj = new Date(drillDownValue);
                            if (!isNaN(dateObj.getTime())) {
                                stepName = dateObj.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' }); // Format date nicely
                            } else { stepName = String(drillDownValue); } // Fallback if invalid date
                        } catch (e) { stepName = String(drillDownValue); } // Fallback on error
                    } else { stepName = String(drillDownValue); } // Fallback
                }


                // Add the new step to the drillDownPath
                // level: The level number this *step represents in the path* (1=Year step, 2=Month step, etc.)
                // The level property in the path object should be drillDownPath.length + 1.
                drillDownPath.push({
                    level: drillDownPath.length + 1,
                    value: drillDownValue, // Store the original value clicked
                    name: stepName, // Store the formatted name for display
                    QueryID: drillQueryDef.DrillDownQueryID // Store the ID of the definition used to get here
                });

                updateBreadcrumbs(); // Update breadcrumbs UI

                // Fetch data for the new drill level using the selected query definition
                fetchAndDisplayReportData(); // fetchAndDisplayReportData will use the updated drillDownPath
            }

            // Function to handle Back button clicks using breadcrumbs logic (Note: Only "All Data" breadcrumb is clickable)
            function handleBreadcrumbClick(targetLevel) {
                // targetLevel 0 means go back to the base report
                if (targetLevel === 0) {
                    drillDownPath = [];
                }
                // More complex logic would prune the path to the target level
                // For this simple setup, only "All Data" (level 0) breadcrumb is clickable,
                // and the Back button handles popping the last step.
                updateBreadcrumbs();
                fetchAndDisplayReportData();
            }


        </script>

        <%-- Removed SignalR script references --%>
    </form>
</body>
</html>
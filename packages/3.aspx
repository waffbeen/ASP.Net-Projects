<%@ Page Language="vb" AutoEventWireup="false" CodeBehind="Viewer.aspx.vb" Inherits="Vision.Viewer" %>

<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>Vision - Data Viewer Panel</title>

    <%-- DevExtreme CSS (केवल नियंत्रणों के लिए) --%>
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
    </style>
</head>
<body>
    <form id="form1" runat="server">
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
        </div>

        <div class="visualization-area">
            <div id="drillDownBreadcrumbs" style="display: none;"></div>
            <div class="data-container">
                <div id="gridContainer"></div> 
                <div id="chartContainer"></div> 
            </div>
        </div>

        <%-- jQuery & DevExtreme JS --%>
        <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
        <script src="https://cdn3.devexpress.com/jslib/23.2.3/js/dx.all.js"></script>
        
        <%-- **NEW LIBRARIES for EXPORT** --%>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/exceljs/4.4.0/exceljs.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf-autotable/3.8.2/jspdf.plugin.autotable.min.js"></script>
        <script>
            // This is required for DevExtreme to find the libraries
            window.ExcelJS = ExcelJS;
            window.jspdf = window.jspdf.jsPDF;
        </script>
        <%-- **END NEW LIBRARIES** --%>


        <script type="text/javascript">
            var reportSelectBox;
            var timeFilterSelectBox;
            var chartTypeSelectBox;
            var dataGridInstance;
            var backButtonInstance;
            var currentDataForCharts = [];

            var currentReportId = null;
            var currentChartType = "GoogleBar"; // Default chart type
            var drillDownPath = []; // Stores objects like { level: 1, value: "2023-01" }

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
                                        d.resolve(result.Reports || []);
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
                    displayExpr: "ReportName",
                    valueExpr: "ReportID",
                    placeholder: "Select a report",
                    onValueChanged: function (e) {
                        currentReportId = e.value;
                        drillDownPath = [];
                        updateBreadcrumbs();
                        fetchAndDisplayReportData();
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
                            drawGoogleChart(currentDataForCharts); // Re-draw with existing data
                        }
                    }
                }).dxSelectBox('instance');

                backButtonInstance = $('#backButtonContainer').dxButton({
                    icon: "back",
                    text: "Back",
                    visible: false,
                    onClick: function () {
                        if (drillDownPath.length > 0) {
                            drillDownPath.pop();
                            updateBreadcrumbs();
                            fetchAndDisplayReportData();
                        }
                    }
                }).dxButton('instance');

                dataGridInstance = $('#gridContainer').dxDataGrid({
                    dataSource: [],
                    columns: [],
                    showBorders: true,
                    paging: { pageSize: 15 },
                    filterRow: { visible: true },
                    headerFilter: { visible: true },
                    searchPanel: { visible: true, width: 240, placeholder: "Search..." },
                    columnChooser: { enabled: true },
                    groupPanel: { visible: true },
                    summary: {
                        totalItems: [{
                            column: "TotalSales", // Change this to a column that makes sense to sum
                            summaryType: "sum",
                            valueFormat: "currency",
                            displayFormat: "Total: {0}"
                        }],
                        groupItems: [{
                            summaryType: "sum",
                            showInGroupFooter: false,
                            alignByColumn: true,
                            displayFormat: "{0}"
                        }]
                    },
                    // **NEW EXPORT FUNCTIONALITY**
                    "export": {
                        enabled: true,
                        formats: ['xlsx', 'pdf'],
                        allowExportSelectedData: true
                    },
                    onExporting: function (e) {
                        if (e.format === 'xlsx') {
                            const workbook = new ExcelJS.Workbook();
                            const worksheet = workbook.addWorksheet('Report');

                            DevExpress.excelExporter.exportDataGrid({
                                component: e.component,
                                worksheet: worksheet,
                                autoFilterEnabled: true
                            }).then(function () {
                                workbook.xlsx.writeBuffer().then(function (buffer) {
                                    saveAs(new Blob([buffer], { type: 'application/octet-stream' }), 'Report.xlsx');
                                });
                            });
                            e.cancel = true;
                        }
                        else if (e.format === 'pdf') {
                            const doc = new jsPDF();
                            DevExpress.pdfExporter.exportDataGrid({
                                jsPDFDocument: doc,
                                component: e.component
                            }).then(function () {
                                doc.save('Report.pdf');
                            });
                        }
                    }
                    // **END NEW EXPORT FUNCTIONALITY**
                }).dxDataGrid('instance');

                google.charts.setOnLoadCallback(function () {
                    console.log("SUCCESS: Google Charts library loaded and ready.");
                    if (reportSelectBox.option('value')) {
                        fetchAndDisplayReportData();
                    }
                });
            });

            // Function to fetch data based on selected report and filters
            function fetchAndDisplayReportData() {
                if (!currentReportId) { return; }

                var timeFilter = timeFilterSelectBox.option('value');
                var currentDrillDownLevel = drillDownPath.length;
                var currentDrillDownValue = currentDrillDownLevel > 0 ? drillDownPath[drillDownPath.length - 1].value : "";

                DevExpress.ui.notify("Loading report data...", "info", 1000);

                $.ajax({
                    type: "POST",
                    url: "Viewer.aspx/GetReportData",
                    data: JSON.stringify({
                        request: {
                            ReportId: currentReportId,
                            TimeFilter: timeFilter,
                            DrillDownLevel: currentDrillDownLevel,
                            DrillDownValue: currentDrillDownValue
                        }
                    }),
                    contentType: "application/json; charset=utf-8",
                    dataType: "json",
                    success: function (response) {
                        var result = response.d;
                        if (result.Success) {
                            var data = result.Data;
                            currentDataForCharts = data;

                            // Update Data Grid
                            var columns = [];
                            if (data && data.length > 0) {
                                for (var prop in data[0]) {
                                    columns.push({ dataField: prop, caption: prop });
                                }
                            }
                            dataGridInstance.option('columns', columns);
                            dataGridInstance.option('dataSource', data);

                            // Draw Google Chart
                            setTimeout(function () {
                                drawGoogleChart(data);
                            }, 50);
                        } else {
                            DevExpress.ui.notify("Error loading report data: " + result.ErrorMessage, "error", 5000);
                        }
                    },
                    error: function (xhr, status, error) {
                        DevExpress.ui.notify("AJAX error fetching report data.", "error", 5000);
                    }
                });
            }

            // The Bulletproof Google Chart Drawing Logic
            function drawGoogleChart(data) {
                try {
                    if (!google.visualization || !google.visualization.arrayToDataTable) { return; }
                    if (!data || data.length === 0) {
                        $('#chartContainer').html('<div style="text-align:center; padding: 20px;">No data for chart.</div>');
                        return;
                    }
                    var dataKeys = Object.keys(data[0]);
                    if (dataKeys.length < 2) {
                        $('#chartContainer').html('<div style="text-align:center; padding: 20px;">Chart requires at least 2 columns.</div>');
                        return;
                    }

                    var argumentField = dataKeys[0];
                    var valueField = dataKeys[1];
                    var dataArray = [[argumentField, valueField]];
                    for (var i = 0; i < data.length; i++) {
                        var arg = String(data[i][argumentField]);
                        var val = Number(data[i][valueField]);
                        if (isNaN(val)) continue;
                        dataArray.push([arg, val]);
                    }

                    var dataTable = google.visualization.arrayToDataTable(dataArray);
                    var reportTitle = getReportTitle();
                    var drillDownTitle = drillDownPath.length > 0 ? " - " + drillDownPath[drillDownPath.length - 1].name : "";
                    var options = {
                        title: reportTitle + drillDownTitle,
                        chartArea: { width: '80%', height: '70%' },
                        legend: { position: 'bottom' },
                    };

                    var chart;
                    switch (currentChartType) {
                        case "GooglePie":
                            chart = new google.visualization.PieChart(document.getElementById('chartContainer'));
                            break;
                        case "GoogleLine":
                            chart = new google.visualization.LineChart(document.getElementById('chartContainer'));
                            break;
                        case "GoogleBar":
                        default:
                            chart = new google.visualization.ColumnChart(document.getElementById('chartContainer'));
                            break;
                    }

                    // Add drill-down click listener for the chart
                    google.visualization.events.addListener(chart, 'select', function () {
                        var selection = chart.getSelection();
                        if (selection.length > 0 && selection[0].row != null) {
                            if (drillDownPath.length >= 3) {
                                DevExpress.ui.notify("Maximum drill down level reached.", "info", 2000);
                                return;
                            }
                            var drillDownValue = dataTable.getValue(selection[0].row, 0);
                            drillDownPath.push({ level: drillDownPath.length + 1, value: drillDownValue, name: drillDownValue });
                            updateBreadcrumbs();
                            fetchAndDisplayReportData();
                        }
                    });

                    chart.draw(dataTable, options);

                } catch (e) {
                    console.error("CRITICAL ERROR during Google Chart drawing:", e);
                    DevExpress.ui.notify("A critical error occurred while drawing the chart.", "error", 5000);
                }
            }

            function updateBreadcrumbs() {
                var breadcrumbsDiv = $('#drillDownBreadcrumbs');
                backButtonInstance.option('visible', drillDownPath.length > 0);

                if (drillDownPath.length > 0) {
                    breadcrumbsDiv.show();
                    var html = '<span class="breadcrumb-item" data-level="0">All Data</span>';
                    for (var i = 0; i < drillDownPath.length; i++) {
                        html += ' > <span class="breadcrumb-item">' + drillDownPath[i].name + '</span>';
                    }
                    breadcrumbsDiv.html(html);

                    $('.breadcrumb-item').off('click').on('click', function () {
                        drillDownPath = []; // Go back to top level
                        updateBreadcrumbs();
                        fetchAndDisplayReportData();
                    });
                } else {
                    breadcrumbsDiv.hide();
                }
            }

            function getReportTitle() {
                return reportSelectBox.option('text') || "Report Visualization";
            }

            // Redraw on window resize
            var resizeTimeout;
            $(window).on('resize', function () {
                clearTimeout(resizeTimeout);
                resizeTimeout = setTimeout(function () {
                    if (currentReportId) {
                        drawGoogleChart(currentDataForCharts);
                    }
                }, 200);
            });

        </script>
    </form>
</body>
</html>           return reportSelectBox.option('text') || "Report Visualization";
            }
        </script>
    </form>
</body>
</html>    } else {
                    breadcrumbsDiv.hide();
                }
            }
        </script>
    </form>
</body>
</html>
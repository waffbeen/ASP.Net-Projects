<%@ Page Language="vb" AutoEventWireup="false" CodeBehind="Creator.aspx.vb" Inherits="Vision.Creator" %>

<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>Vision - Report Creator Panel</title>
    <link rel="stylesheet" href="https://cdn3.devexpress.com/jslib/23.2.3/css/dx.common.css" />
    <link rel="stylesheet" href="https://cdn3.devexpress.com/jslib/23.2.3/css/dx.light.css" />
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.34.0/min/vs/editor/editor.main.min.css" />
    <style>
        body, html { margin: 0; padding: 0; height: 100%; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; overflow: hidden; }
        body { display: flex; flex-direction: column; }
        .header { background-color: #1588e6; color: white; padding: 15px 20px; text-align: center; font-size: 1.4em; letter-spacing: 1px; }
        .content-area { flex-grow: 1; display: flex; height: calc(100% - 65px); background: #f7fafc; }
        .left-panel, .right-panel { padding: 28px 24px; box-sizing: border-box; overflow-y: auto; }
        .left-panel { flex-basis: 35%; max-width: 35%; border-right: 1px solid #e0e0e0; background: #f3f9fe; }
        .right-panel { flex-basis: 65%; max-width: 65%; display: flex; flex-direction: column; }
        .dx-fieldset { margin-bottom: 24px; padding: 0; border: none; }
        .dx-fieldset-header { font-size: 1.22em; font-weight: bold; margin-bottom: 10px; color: #2261a9; border-bottom: 2px solid #1588e6; padding-bottom: 6px; background: transparent; }
        /* Adjust editor height now that preview grid is below */
        #monacoEditorContainer { height: 400px; border: 1px solid #cfd8dc; margin-bottom: 16px; border-radius: 4px; }
        #livePreviewGridContainer { flex-grow: 1; border: 1px solid #cfd8dc; border-radius: 4px; background: #fff; min-height: 200px; } /* Ensure grid has some height */

        .button-group { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; margin-bottom: 8px; }
        .chart-select-row { margin: 18px 0 0 0; display: flex; align-items: center; gap: 12px; }
        .report-manage-group { display: flex; gap: 10px; margin-top: 10px; margin-bottom: 10px; }
        .template-manage-group { display: flex; gap: 10px; margin-top: 10px; margin-bottom: 10px; }
        .template-select-row { display: flex; align-items: center; gap: 10px; margin-bottom: 10px; }

        /* Hide elements for simplified version */
        #runLevel1Button,
        #runNextLevelButton,
        #updateCurrentLevelButton,
        #prevLevelButton,
        #nextLevelButton,
        #resetLiveSessionButton,
        #liveStatusIndicator,
        #argumentColumnTextBox,
        /* Hide drill-down definition section elements */
        .drill-definitions-header,
        #drillLevelsListContainer,
        #drillSqlEditorContainer,
        #drillLevelTextBox,
        #drillQueryNameTextBox,
        #drillArgumentColumnTextBox,
        #addDrillLevelButton,
        #updateDrillLevelButton,
        #deleteDrillLevelButton
         {
            display: none !important;
        }
    </style>
</head>
<body>
    <form id="form1" runat="server">
        <div class="header">🛠️ Smart SQL Dynamic Reporting — Creator Panel</div>
        <div class="content-area">
            <div class="left-panel">
                <div class="dx-fieldset">
                    <div class="dx-fieldset-header">Report Details</div>
                    <div id="reportNameTextBox"></div>
                    <div class="chart-select-row">
                        <span style="font-weight:600;">Default Chart Type:</span>
                        <div id="chartTypeSelector"></div>
                    </div>
                    <div class="report-manage-group">
                        <div id="saveReportButtonContainer"></div>
                        <div id="renameReportButtonContainer"></div>
                        <div id="deleteReportButtonContainer"></div>
                        <div id="reportPickerContainer"></div>
                    </div>
                </div>
                <div class="dx-fieldset" style="margin-top: 30px;">
                    <div class="dx-fieldset-header">Query Templates</div>
                    <div class="template-select-row">
                        <div id="queryTemplateSelectBoxContainer"></div>
                        <div id="saveTemplateButtonContainer"></div>
                        <div id="deleteTemplateButtonContainer"></div>
                        <div id="renameTemplateButtonContainer"></div>
                    </div>
                </div>
            </div>
            <div class="right-panel">
                <div class="dx-fieldset">
                    <div class="dx-fieldset-header">SQL Editor (Level 1 Base Query)</div>
                    <div id="monacoEditorContainer"></div>
                     <div class="button-group">
                         <div id="runPreviewButton"></div>
                     </div>
                </div>
                <div class="dx-fieldset" style="flex-grow: 1; display: flex; flex-direction: column;">
                    <div class="dx-fieldset-header">Local Data Preview</div>
                    <div id="livePreviewGridContainer"></div>
                </div>
            </div>
        </div>

        <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
        <script src="https://cdn3.devexpress.com/jslib/23.2.3/js/dx.all.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.34.0/min/vs/loader.min.js"></script>
        <script type="text/javascript">
            // Global variables
            var editor, livePreviewGrid, reportNameTextBox, queryTemplateSelectBox;
            var runPreviewButton; // Renamed/Simplified button

            var chartType = "GoogleBar"; // Initial default value
            var chartTypes = [
                { text: "Bar Chart", value: "GoogleBar" },
                { text: "Pie Chart", value: "GooglePie" },
                { text: "Line Chart", value: "GoogleLine" },
                { text: "Table", value: "GoogleTable" }
            ];

            var currentReportId = 0; // 0 means new report
            var currentTemplateId = null; // Selected template ID
            var templateList = []; // List of available templates


            require.config({ paths: { 'vs': 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.34.0/min/vs' } });
            require(['vs/editor/editor.main'], function () {
                editor = monaco.editor.create(document.getElementById('monacoEditorContainer'), {
                    value: "SELECT YEAR(OrderDate) as [Year], SUM(Total) as TotalSales, COUNT(DISTINCT OrderID) as NumberOfOrders\nFROM AmazonSalesData\nGROUP BY YEAR(OrderDate)\nORDER BY [Year];", // Default query suggestion (Base query for date hierarchy)
                    language: 'sql', theme: 'vs-light', automaticLayout: true
                });
            });

            // --- Report Management Functions ---
            function loadReportsList() {
                $.ajax({
                    type: "POST", url: "Creator.aspx/GetAllReports", contentType: "application/json; charset=utf-8", dataType: "json",
                    success: function (response) {
                        var result = response.d;
                        if (result.Success) {
                            var data = result.Data || [];
                            // Get existing instance or create new one
                            var reportPicker = $("#reportPickerContainer").dxSelectBox("instance");
                            if (reportPicker) {
                                reportPicker.option("dataSource", data);
                            } else {
                                $("#reportPickerContainer").dxSelectBox({
                                    dataSource: data,
                                    displayExpr: "ReportName",
                                    valueExpr: "ReportID",
                                    placeholder: "Pick Report",
                                    width: 170,
                                    onValueChanged: function (e) { if (e.value) { loadReport(e.value); } else { resetCreatorState(); } }
                                }).dxSelectBox('instance');
                            }
                        } else {
                            DevExpress.ui.notify("Error loading reports: " + result.ErrorMessage, "error", 3000);
                        }
                    },
                    error: function () {
                        DevExpress.ui.notify("Network error loading reports.", "error", 3000);
                    }
                });
            }

            function loadReport(reportId) {
                resetCreatorState(true);
                currentReportId = reportId;
                reportNameTextBox.option('value', 'Loading...');
                editor.setValue('Loading...');
                livePreviewGrid.option('dataSource', []);
                livePreviewGrid.option('columns', []);

                $.ajax({
                    type: "POST", url: "Creator.aspx/GetReportById", contentType: "application/json; charset=utf-8", dataType: "json",
                    data: JSON.stringify({ reportId: reportId }),
                    success: function (response) {
                        var result = response.d;
                        if (result.Success && result.Data) {
                            currentReportId = result.Data.ReportID;
                            reportNameTextBox.option('value', result.Data.ReportName);
                            editor.setValue(result.Data.SQLQuery || "");
                            chartType = result.Data.ChartType || "GoogleBar";
                            $("#chartTypeSelector").dxSelectBox("instance").option("value", chartType);
                            DevExpress.ui.notify("Report loaded.", "success", 1500);
                        } else {
                            DevExpress.ui.notify("Error loading report: " + result.ErrorMessage, "error", 4000);
                            resetCreatorState();
                        }
                    },
                    error: function () {
                        DevExpress.ui.notify("Network error loading report.", "error", 4000);
                        resetCreatorState();
                    }
                });
            }

            function resetCreatorState(isSilent = false) {
                currentReportId = 0;
                reportNameTextBox.option('value', '');
                editor.setValue("SELECT YEAR(OrderDate) as [Year], SUM(Total) as TotalSales, COUNT(DISTINCT OrderID) as NumberOfOrders\nFROM AmazonSalesData\nGROUP BY YEAR(OrderDate)\nORDER BY [Year];");
                livePreviewGrid.option({ 'dataSource': [], 'columns': [] });
                var reportPicker = $("#reportPickerContainer").dxSelectBox("instance");
                if (reportPicker) {
                    reportPicker.option("value", null);
                }
                $("#chartTypeSelector").dxSelectBox("instance").option("value", "GoogleBar");

                if (!isSilent) {
                    DevExpress.ui.notify("Creator state reset (New Report).", "info", 1000);
                }
            }

            function saveReport() {
                var reportName = reportNameTextBox.option('value');
                var baseSqlQuery = editor.getValue();

                if (!reportName || !baseSqlQuery || reportName.trim() === "" || baseSqlQuery.trim() === "") {
                    DevExpress.ui.notify('Report Name and SQL Query cannot be empty.', 'error', 3000);
                    return;
                }

                var requestPayload = {
                    ReportId: currentReportId,
                    ReportName: reportName,
                    SQLQuery: baseSqlQuery,
                    ChartType: chartType
                };

                DevExpress.ui.notify('Saving report...', 'info', 1000);
                $.ajax({
                    type: "POST", url: "Creator.aspx/SaveReport", contentType: "application/json; charset=utf-8", dataType: "json", data: JSON.stringify({ reportData: requestPayload }),
                    success: function (response) {
                        var result = response.d;
                        if (result.Success) {
                            DevExpress.ui.notify('Report saved successfully!', 'success', 3000);
                            currentReportId = result.Data.NewReportId;
                            loadReportsList();
                            setTimeout(function () {
                                var reportPicker = $("#reportPickerContainer").dxSelectBox("instance");
                                if (reportPicker) {
                                    reportPicker.option("value", currentReportId);
                                }
                            }, 200);

                        } else { DevExpress.ui.notify('Error saving report: ' + result.ErrorMessage, 'error', 5000); }
                    },
                    error: function (xhr, status, error) {
                        DevExpress.ui.notify('AJAX error saving report: ' + xhr.statusText, 'error', 5000);
                        console.error("AJAX Error:", status, error, xhr);
                    }
                });
            }


            function deleteReport() {
                if (!currentReportId) { DevExpress.ui.notify('No report selected.', 'error', 2000); return; }
                if (!confirm("Delete current report? This will also delete associated drill-down definitions, versions, and views.")) return;
                $.ajax({
                    type: "POST", url: "Creator.aspx/DeleteReport", contentType: "application/json; charset=utf-8", dataType: "json",
                    data: JSON.stringify({ reportId: currentReportId }),
                    success: function (response) {
                        var result = response.d;
                        if (result.Success) {
                            DevExpress.ui.notify('Report deleted.', "success", 1800);
                            resetCreatorState();
                            loadReportsList();
                        } else {
                            DevExpress.ui.notify('Delete failed: ' + result.ErrorMessage, "error", 3500);
                        }
                    },
                    error: function () {
                        DevExpress.ui.notify("Network error deleting report.", "error", 3000);
                    }
                });
            }

            function renameReport() {
                if (!currentReportId) { DevExpress.ui.notify('No report selected.', "error", 2000); return; }
                var currentName = reportNameTextBox.option('value');
                var newName = prompt("New report name:", currentName);
                if (!newName || newName === currentName) return;
                if (newName.trim() === "") { DevExpress.ui.notify("Report name cannot be empty.", "warning", 2000); return; }

                $.ajax({
                    type: "POST", url: "Creator.aspx/RenameReport", contentType: "application/json; charset=utf-8", dataType: "json",
                    data: JSON.stringify({ reportId: currentReportId, newName: newName }),
                    success: function (response) {
                        var result = response.d;
                        if (result.Success) {
                            DevExpress.ui.notify('Report renamed.', "success", 1500);
                            reportNameTextBox.option('value', newName);
                            loadReportsList();
                        } else {
                            DevExpress.ui.notify(response.d.ErrorMessage, "error", 3500);
                        }
                    },
                    error: function () {
                        DevExpress.ui.notify("Network error renaming report.", "error", 3000);
                    }
                });
            }

            // --- Template Management Functions ---
            function loadTemplatesList() {
                $.ajax({
                    type: "POST", url: "Creator.aspx/GetAllTemplates", contentType: "application/json; charset=utf-8", dataType: "json",
                    success: function (response) {
                        var result = response.d;
                        if (result.Success) {
                            templateList = result.Data || [];
                            var templateSelect = $('#queryTemplateSelectBoxContainer').dxSelectBox("instance");
                            if (templateSelect) {
                                templateSelect.option("dataSource", templateList);
                            } else {
                                $('#queryTemplateSelectBoxContainer').dxSelectBox({
                                    dataSource: templateList, displayExpr: "TemplateName", valueExpr: "TemplateID",
                                    placeholder: "Load a template", onOpened: loadTemplatesList,
                                    onValueChanged: function (e) { if (e.value) { loadTemplateById(e.value); } }
                                }).dxSelectBox('instance');
                            }
                        } else {
                            DevExpress.ui.notify("Error loading templates: " + result.ErrorMessage, "error", 3000);
                        }
                    },
                    error: function () {
                        DevExpress.ui.notify("Network error loading templates.", "error", 3000);
                    }
                });
            }

            function saveTemplate() {
                var templateName = prompt("Enter template name:");
                var sqlText = editor.getValue();
                if (!templateName || sqlText.trim() === "" || templateName.trim() === "") {
                    DevExpress.ui.notify("Template Name and SQL are required.", "error", 2500);
                    return;
                }

                var templateId = $('#queryTemplateSelectBoxContainer').dxSelectBox("instance").option("value") || 0;
                if (templateId > 0) {
                    if (!confirm(`Overwrite template "${$('#queryTemplateSelectBoxContainer').dxSelectBox("instance").option("text")}"?`)) {
                        return;
                    }
                }

                var templateData = { TemplateID: templateId, TemplateName: templateName, Description: "", SQLQueryTemplate: sqlText };

                $.ajax({
                    type: "POST", url: "Creator.aspx/SaveQueryTemplate", contentType: "application/json; charset=utf-8", dataType: "json",
                    data: JSON.stringify({ templateData: templateData }),
                    success: function (response) {
                        if (response.d.Success) {
                            DevExpress.ui.notify("Template saved.", "success", 1500);
                            loadTemplatesList();
                            if (templateId === 0 && response.d.Data && response.d.Data.NewTemplateID) {
                                $('#queryTemplateSelectBoxContainer').dxSelectBox("instance").option("value", response.d.Data.NewTemplateID);
                            }
                        } else {
                            DevExpress.ui.notify(response.d.ErrorMessage, "error", 3500);
                        }
                    },
                    error: function () {
                        DevExpress.ui.notify("Network error saving template.", "error", 3000);
                    }
                });
            }
            function deleteTemplate() {
                var tId = $('#queryTemplateSelectBoxContainer').dxSelectBox("instance").option("value");
                var templateName = $('#queryTemplateSelectBoxContainer').dxSelectBox("instance").option("text");
                if (!tId) { DevExpress.ui.notify("Select a template to delete.", "error", 1500); return; }
                if (!confirm(`Delete template "${templateName}"?`)) return;
                $.ajax({
                    type: "POST", url: "Creator.aspx/DeleteQueryTemplate", contentType: "application/json; charset=utf-8", dataType: "json",
                    data: JSON.stringify({ templateId: tId }),
                    success: function (response) {
                        if (response.d.Success) {
                            DevExpress.ui.notify("Template deleted.", "success", 1500);
                            $('#queryTemplateSelectBoxContainer').dxSelectBox("instance").option("value", null);
                            loadTemplatesList();
                        } else {
                            DevExpress.ui.notify(response.d.ErrorMessage, "error", 3500);
                        }
                    },
                    error: function () {
                        DevExpress.ui.notify("Network error deleting template.", "error", 3000);
                    }
                });
            }
            function renameTemplate() {
                var tId = $('#queryTemplateSelectBoxContainer').dxSelectBox("instance").option("value");
                var currentName = $('#queryTemplateSelectBoxContainer').dxSelectBox("instance").option("text");
                if (!tId) { DevExpress.ui.notify("Select a template to rename.", "error", 1500); return; }
                var newName = prompt("New template name:", currentName);
                if (!newName || newName === currentName) return;
                if (newName.trim() === "") { DevExpress.ui.notify("Template name cannot be empty.", "warning", 2000); return; }

                $.ajax({
                    type: "POST", url: "Creator.aspx/RenameQueryTemplate", contentType: "application/json; charset=utf-8", dataType: "json",
                    data: JSON.stringify({ templateId: tId, newName: newName }),
                    success: function (response) {
                        var result = response.d;
                        if (result.Success) {
                            DevExpress.ui.notify("Template renamed.", "success", 1500);
                            loadTemplatesList();
                        } else {
                            DevExpress.ui.notify(response.d.ErrorMessage, "error", 3500);
                        }
                    },
                    error: function () {
                        DevExpress.ui.notify("Network error renaming template.", "error", 3000);
                    }
                });
            }
            function loadTemplateById(templateId) {
                var templateSelectBox = $('#queryTemplateSelectBoxContainer').dxSelectBox("instance");
                var originalValue = templateSelectBox.option("value");
                if (originalValue === templateId) {
                    templateSelectBox.option("value", null);
                    setTimeout(function () { templateSelectBox.option("value", originalValue); }, 10);
                }


                $.ajax({
                    type: "POST", url: "Creator.aspx/GetTemplateById", contentType: "application/json; charset=utf-8", dataType: "json",
                    data: JSON.stringify({ templateId: templateId }),
                    success: function (response) {
                        if (response.d.Success && response.d.Data) {
                            editor.setValue(response.d.Data.SQLQueryTemplate);
                            DevExpress.ui.notify("Template loaded.", "success", 1000);
                        } else {
                            DevExpress.ui.notify("Error loading template: " + response.d.ErrorMessage, "error", 3000);
                        }
                    },
                    error: function () {
                        DevExpress.ui.notify("Network error loading template.", "error", 3000);
                    }
                });
            }

            // --- Preview Function ---
            function runPreviewQuery() {
                if (!editor) return;
                var sqlQuery = editor.getValue();
                if (!sqlQuery || sqlQuery.trim() === "") {
                    DevExpress.ui.notify('SQL Query cannot be empty.', "error", 2000);
                    return;
                }

                runPreviewButton.option('disabled', true);
                runPreviewButton.option('text', 'Running...');
                DevExpress.ui.notify('Executing query for preview...', "info", 1000);

                $.ajax({
                    type: "POST",
                    url: "Creator.aspx/RunPreviewQuery",
                    contentType: "application/json; charset=utf-8",
                    dataType: "json",
                    data: JSON.stringify({ sqlQuery: sqlQuery }),
                    success: function (response) {
                        var result = response.d;
                        if (result.Success) {
                            DevExpress.ui.notify('Preview loaded!', "success", 1000);
                            livePreviewGrid.option('dataSource', result.Data.LocalData || []);
                            livePreviewGrid.option('columns', (result.Data.LocalData && result.Data.LocalData.length > 0) ? Object.keys(result.Data.LocalData[0]).map(c => ({ dataField: c, caption: c })) : []);

                        } else {
                            livePreviewGrid.option('dataSource', []);
                            livePreviewGrid.option('columns', []);
                            DevExpress.ui.notify('Preview Failed: ' + result.ErrorMessage, "error", 6000);
                            console.error("Preview Failed:", result.ErrorMessage);
                        }
                    },
                    error: function (xhr, status, error) {
                        DevExpress.ui.notify('AJAX error running preview: ' + xhr.statusText, "error", 6000);
                        console.error("AJAX Error:", status, error, xhr);
                        livePreviewGrid.option('dataSource', []);
                        livePreviewGrid.option('columns', []);
                    },
                    complete: function () {
                        runPreviewButton.option('disabled', false);
                        runPreviewButton.option('text', '▶️ Run Preview');
                    }
                });
            }

        </script>
    </form>
</body>
</html>
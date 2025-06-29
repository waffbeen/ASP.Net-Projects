<%@ Page Language="vb" AutoEventWireup="false" CodeBehind="Creator.aspx.vb" Inherits="Vision.Creator" %>

<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>Vision - Report Creator Panel</title>
    <%-- DevExtreme CSS --%>
    <link rel="stylesheet" href="https://cdn3.devexpress.com/jslib/23.2.3/css/dx.common.css" />
    <link rel="stylesheet" href="https://cdn3.devexpress.com/jslib/23.2.3/css/dx.light.css" />
    <%-- Monaco Editor CSS --%>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.34.0/min/vs/editor/editor.main.min.css" />
    
    <style>
        /* General Layout & Colors */
        body, html { margin: 0; padding: 0; height: 100%; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; overflow: hidden; background-color: #f0f2f5; }
        body { display: flex; flex-direction: column; }
        .header { background-color: #0056b3; color: white; padding: 18px 25px; text-align: center; font-size: 1.6em; letter-spacing: 1px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .content-area { flex-grow: 1; display: flex; height: calc(100% - 70px); padding: 20px; box-sizing: border-box; }
        
        /* Panel Styling */
        .left-panel, .right-panel {
            background-color: #ffffff;
            border-radius: 8px;
            box-shadow: 0 4px 10px rgba(0,0,0,0.05);
            padding: 25px;
            box-sizing: border-box;
            overflow-y: auto;
            margin: 0 10px; /* Space between panels */
        }
        .left-panel { flex-basis: 30%; min-width: 300px; max-width: 400px; }
        .right-panel { flex-basis: 70%; flex-grow: 1; display: flex; flex-direction: column; }

        /* Fieldset & Header Styling */
        .dx-fieldset { margin-bottom: 30px; padding: 0; border: none; }
        .dx-fieldset-header { 
            font-size: 1.3em; 
            font-weight: 600; 
            margin-bottom: 15px; 
            color: #0056b3; 
            border-bottom: 3px solid #007bff; 
            padding-bottom: 8px; 
            margin-top: 0;
        }

        /* Monaco Editor & Grid */
        #monacoEditorContainer { height: 350px; border: 1px solid #dcdfe6; margin-bottom: 20px; border-radius: 5px; }
        #livePreviewGridContainer { flex-grow: 1; border: 1px solid #dcdfe6; border-radius: 5px; background: #fff; min-height: 250px; }

        /* Button & Control Groups */
        .button-group { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; margin-bottom: 15px; }
        .control-row { margin-bottom: 15px; } /* Consistent spacing for rows of controls */
        .control-label { font-weight: 600; color: #555; margin-bottom: 5px; display: block; } /* For labels above controls */

        /* Specific DevExtreme Adjustments */
        .dx-selectbox, .dx-textbox, .dx-button { margin-top: 5px; } /* Small top margin for consistency */
        .dx-textbox-multiline { min-height: 80px; } /* Ensure multiline textboxes have enough space */

        /* Hide Live Session Elements */
        /* These are NOT used in the simplified model and are explicitly hidden */
        #runLevel1Button, #runNextLevelButton, #updateCurrentLevelButton,
        #prevLevelButton, #nextLevelButton, #resetLiveSessionButton,
        #liveStatusIndicator, .dx-button.selected-chart, /* friend's custom class, not needed */
        #reportDescriptionTextBox + .dx-textbox-container, /* Hide the container if ReportDescription is not used in JS */
        #allowedUsersTextBox + .dx-textbox-container /* Hide the container if AllowedUsers is not used in JS */
        {
            display: none !important;
        }

        /* Ensure controls have default sizing if not specified by DevExtreme */
        .dx-selectbox, .dx-textbox { width: 100%; max-width: 300px; } /* Default width, adjust as needed */
        #reportPickerContainer { width: 100%; max-width: 170px; } /* Specific for report picker */
        #queryTemplateSelectBoxContainer { width: 100%; max-width: 200px; } /* Specific for template picker */

    </style>
</head>
<body>
    <form id="form1" runat="server">
        <div class="header">🛠️ Smart SQL Dynamic Reporting — Creator Panel</div>
        <div class="content-area">
            <div class="left-panel">
                <div class="dx-fieldset">
                    <div class="dx-fieldset-header">Report Details</div>
                    
                    <div class="control-row">
                        <div class="control-label">Report Name:</div>
                        <div id="reportNameTextBox"></div>
                    </div>
                    
                    <div class="control-row">
                        <div class="control-label">Description:</div>
                        <div id="reportDescriptionTextBox"></div>
                    </div>

                    <div class="control-row">
                        <div class="control-label">Allowed Users (CSV):</div>
                        <div id="allowedUsersTextBox"></div>
                    </div>

                    <div class="control-row">
                        <div class="control-label">Default Chart Type:</div>
                        <div id="chartTypeSelector"></div>
                    </div>
                    
                    <div class="button-group report-manage-group">
                        <div id="saveReportButtonContainer"></div>
                        <div id="renameReportButtonContainer"></div>
                        <div id="deleteReportButtonContainer"></div>
                        <div id="reportPickerContainer"></div>
                    </div>
                </div>

                <div class="dx-fieldset">
                    <div class="dx-fieldset-header">Query Templates</div>
                    <div class="button-group template-select-row">
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
                        <div id="runPreviewButton"></div> <%-- Only this button is active for preview --%>
                        <%-- Removed other live session buttons --%>
                    </div>
                </div>
                <div class="dx-fieldset" style="flex-grow: 1; display: flex; flex-direction: column;">
                    <div class="dx-fieldset-header">Local Data Preview</div>
                    <div id="livePreviewGridContainer"></div>
                </div>
            </div>
        </div>
        
        <%-- jQuery & DevExtreme JS --%>
        <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
        <script src="https://cdn3.devexpress.com/jslib/23.2.3/js/dx.all.js"></script>
        <%-- Monaco Editor JS --%>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.34.0/min/vs/loader.min.js"></script>
        <%-- Removed SignalR script references --%>

        <script type="text/javascript">
            // Global variables
            var editor, livePreviewGrid, reportNameTextBox, reportDescriptionTextBox, allowedUsersTextBox, chartTypeSelector, reportPickerSelectBox, queryTemplateSelectBox;
            var runPreviewButton; // Only this one remains

            var chartType = "GoogleBar"; // Initial default value (consistent with Viewer)
            var chartTypes = [
                { text: "Bar Chart", value: "GoogleBar" },
                { text: "Pie Chart", value: "GooglePie" },
                { text: "Line Chart", value: "GoogleLine" },
                { text: "Table", value: "GoogleTable" } // For grid-only display
            ];

            var currentReportId = 0; // 0 means new report
            var currentTemplateId = null; // Selected template ID
            var templateList = []; // List of available templates


            require.config({ paths: { 'vs': 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.34.0/min/vs' } });
            require(['vs/editor/editor.main'], function () {
                editor = monaco.editor.create(document.getElementById('monacoEditorContainer'), {
                    value: "SELECT YEAR(OrderDate) as [Year], SUM(Total) as TotalSales, COUNT(DISTINCT OrderID) as NumberOfOrders\nFROM AmazonSalesData\nGROUP BY YEAR(OrderDate)\nORDER BY [Year];", // Default query suggestion
                    language: 'sql', theme: 'vs-light', automaticLayout: true
                });
            });

            $(function () {
                // Initialize Report Details controls
                reportNameTextBox = $('#reportNameTextBox').dxTextBox({ placeholder: 'Report Name' }).dxTextBox('instance');
                reportDescriptionTextBox = $('#reportDescriptionTextBox').dxTextBox({ placeholder: 'Brief description of the report', mode: 'multiline', height: 90, stylingMode: 'outlined' }).dxTextBox('instance');
                allowedUsersTextBox = $('#allowedUsersTextBox').dxTextBox({ placeholder: 'e.g., 1,Admin,User,All', stylingMode: 'outlined' }).dxTextBox('instance');

                chartTypeSelector = $('#chartTypeSelector').dxSelectBox({
                    dataSource: chartTypes,
                    displayExpr: "text",
                    valueExpr: "value",
                    value: chartType, // Set initial value from global var
                    stylingMode: "outlined",
                    onValueChanged: function (e) { chartType = e.value; }
                }).dxSelectBox('instance');

                $('#saveReportButtonContainer').dxButton({ text: 'Save Report', icon: 'save', type: 'success', onClick: saveReport });
                $('#renameReportButtonContainer').dxButton({ text: 'Rename', icon: 'edit', type: 'default', onClick: renameReport });
                $('#deleteReportButtonContainer').dxButton({ text: 'Delete', icon: 'trash', type: 'danger', onClick: deleteReport });

                // Report Picker is initialized in loadReportsList for dynamic data
                loadReportsList();


                // Initialize Query Templates controls
                $('#saveTemplateButtonContainer').dxButton({ text: 'Save Template', icon: 'save', type: 'success', onClick: saveTemplate });
                $('#deleteTemplateButtonContainer').dxButton({ text: 'Delete', icon: 'trash', type: 'danger', onClick: deleteTemplate });
                $('#renameTemplateButtonContainer').dxButton({ text: 'Rename', icon: 'edit', type: 'default', onClick: renameTemplate });

                // Query Template SelectBox is initialized in loadTemplatesList for dynamic data
                loadTemplatesList();


                // Initialize Run Preview button
                runPreviewButton = $('#runPreviewButton').dxButton({
                    text: '▶️ Run Preview', type: 'default', onClick: runPreviewQuery
                }).dxButton('instance');

                // Initialize Live Data Preview Grid
                livePreviewGrid = $('#livePreviewGridContainer').dxDataGrid({
                    dataSource: [], columns: [], showBorders: true, paging: { pageSize: 10 }, columnAutoWidth: true,
                    filterRow: { visible: true }, headerFilter: { visible: true }, searchPanel: { visible: true, width: 240 }
                }).dxDataGrid('instance');

                // Reset state on initial load
                resetCreatorState(true);
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
                                reportPicker = $("#reportPickerContainer").dxSelectBox({
                                    dataSource: data,
                                    displayExpr: "ReportName",
                                    valueExpr: "ReportID",
                                    placeholder: "Pick Report",
                                    width: '100%', // Use 100% width within its container
                                    onValueChanged: function (e) {
                                        if (e.value) { loadReport(e.value); } else { resetCreatorState(); }
                                    }
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
                // Reset UI first, silently
                resetCreatorState(true);
                currentReportId = reportId; // Set currentReportId immediately

                // Show loading states
                reportNameTextBox.option('value', 'Loading...');
                reportDescriptionTextBox.option('value', 'Loading...');
                allowedUsersTextBox.option('value', 'Loading...');
                editor.setValue('Loading...');
                livePreviewGrid.option('dataSource', []);
                livePreviewGrid.option('columns', []);

                $.ajax({
                    type: "POST", url: "Creator.aspx/GetReportById", contentType: "application/json; charset=utf-8", dataType: "json",
                    data: JSON.stringify({ reportId: reportId }),
                    success: function (response) {
                        var result = response.d;
                        if (result.Success && result.Data) {
                            currentReportId = result.Data.ReportID; // Confirm loaded ID
                            reportNameTextBox.option('value', result.Data.ReportName || '');
                            reportDescriptionTextBox.option('value', result.Data.ReportDescription || '');
                            allowedUsersTextBox.option('value', result.Data.AllowedUsersCSV || '');

                            editor.setValue(result.Data.SQLQuery || ""); // Base Level 1 Query
                            chartType = result.Data.ChartType || "GoogleBar";
                            chartTypeSelector.option("value", chartType); // Update chart type selector UI

                            DevExpress.ui.notify("Report loaded.", "success", 1500);

                        } else {
                            DevExpress.ui.notify("Error loading report: " + result.ErrorMessage, "error", 4000);
                            resetCreatorState(); // Reset UI on load failure
                        }
                    },
                    error: function () {
                        DevExpress.ui.notify("Network error loading report.", "error", 4000);
                        resetCreatorState(); // Reset UI on load failure
                    }
                });
            }

            function resetCreatorState(isSilent = false) {
                currentReportId = 0; // Indicates no report is loaded
                reportNameTextBox.option('value', '');
                reportDescriptionTextBox.option('value', '');
                allowedUsersTextBox.option('value', 'All'); // Default to 'All' or empty
                editor.setValue("SELECT YEAR(OrderDate) as [Year], SUM(Total) as TotalSales, COUNT(DISTINCT OrderID) as NumberOfOrders\nFROM AmazonSalesData\nGROUP BY YEAR(OrderDate)\nORDER BY [Year];"); // Default query suggestion
                livePreviewGrid.option({ 'dataSource': [], 'columns': [] }); // Clear preview grid

                // Clear report picker selection without triggering loadReport
                var reportPicker = $("#reportPickerContainer").dxSelectBox("instance");
                if (reportPicker) {
                    reportPicker.option("value", null);
                }
                chartTypeSelector.option("value", "GoogleBar"); // Reset chart type

                if (!isSilent) {
                    DevExpress.ui.notify("Creator state reset (New Report).", "info", 1000);
                }
            }

            function saveReport() {
                var reportName = reportNameTextBox.option('value');
                var reportDescription = reportDescriptionTextBox.option('value');
                var allowedUsers = allowedUsersTextBox.option('value');
                var baseSqlQuery = editor.getValue();

                if (!reportName || reportName.trim() === "" ||
                    !baseSqlQuery || baseSqlQuery.trim() === "" ||
                    !allowedUsers || allowedUsers.trim() === "") {
                    DevExpress.ui.notify('Report Name, SQL Query, and Allowed Users are required fields.', 'error', 4000);
                    return;
                }

                var requestPayload = {
                    ReportId: currentReportId,
                    ReportName: reportName,
                    ReportDescription: reportDescription, // Pass description
                    SQLQuery: baseSqlQuery,
                    ChartType: chartType,
                    AllowedUsersCSV: allowedUsers // Pass allowed users
                };

                DevExpress.ui.notify('Saving report...', 'info', 1000);
                $.ajax({
                    type: "POST", url: "Creator.aspx/SaveReport", contentType: "application/json; charset=utf-8", dataType: "json", data: JSON.stringify({ reportData: requestPayload }),
                    success: function (response) {
                        var result = response.d;
                        if (result.Success) {
                            DevExpress.ui.notify('Report saved successfully!', "success", 3000);
                            currentReportId = result.Data.NewReportId; // Update currentReportId if new report
                            loadReportsList(); // Reload report list picker
                            setTimeout(function () {
                                var reportPicker = $("#reportPickerContainer").dxSelectBox("instance");
                                if (reportPicker) {
                                    reportPicker.option("value", currentReportId); // Select the newly saved report
                                }
                            }, 200);

                        } else { DevExpress.ui.notify('Error saving report: ' + result.ErrorMessage, "error", 5000); }
                    },
                    error: function (xhr, status, error) {
                        DevExpress.ui.notify('AJAX error saving report: ' + xhr.statusText, "error", 5000);
                        console.error("AJAX Error:", status, error, xhr);
                    }
                });
            }


            function deleteReport() {
                if (!currentReportId) { DevExpress.ui.notify('No report selected.', "error", 2000); return; }
                if (!confirm("Delete current report? This will also delete associated drill-down definitions, versions, and views.")) return;
                $.ajax({
                    type: "POST", url: "Creator.aspx/DeleteReport", contentType: "application/json; charset=utf-8", dataType: "json",
                    data: JSON.stringify({ reportId: currentReportId }),
                    success: function (response) {
                        var result = response.d;
                        if (result.Success) {
                            DevExpress.ui.notify('Report deleted.', "success", 1800);
                            resetCreatorState(); // Reset UI after deletion
                            loadReportsList(); // Reload report list
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
                            loadReportsList(); // Reload list to show new name
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
                                queryTemplateSelectBox = $('#queryTemplateSelectBoxContainer').dxSelectBox({
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
                if (!templateName || templateName.trim() === "" || !sqlText || sqlText.trim() === "") {
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
<%@ Page Language="vb" AutoEventWireup="false" CodeBehind="1.aspx.vb" Inherits="Vision.Creator" %>

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
        #monacoEditorContainer { height: 260px; border: 1px solid #cfd8dc; margin-bottom: 16px; border-radius: 4px; }
        #livePreviewGridContainer { flex-grow: 1; border: 1px solid #cfd8dc; border-radius: 4px; background: #fff; }
        .button-group { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; margin-bottom: 8px; }
        .chart-select-row { margin: 18px 0 0 0; display: flex; align-items: center; gap: 12px; }
        .report-manage-group { display: flex; gap: 10px; margin-top: 10px; margin-bottom: 10px; }
        .template-manage-group { display: flex; gap: 10px; margin-top: 10px; margin-bottom: 10px; }
        .template-select-row { display: flex; align-items: center; gap: 10px; margin-bottom: 10px; }
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
                        <span style="font-weight:600;">Chart Type:</span>
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
                    <div class="dx-fieldset-header">Live Preview SQL Editor</div>
                    <div id="monacoEditorContainer"></div>
                    <div id="argumentColumnTextBox" style="margin-top: 10px; margin-bottom: 10px;"></div>
                    <div class="button-group">
                        <div id="runLevel1Button"></div>
                        <div id="runNextLevelButton"></div>
                        <div id="updateCurrentLevelButton"></div>
                        <div id="prevLevelButton"></div>
                        <div id="nextLevelButton"></div>
                        <div id="resetLiveSessionButton"></div>
                        <div id="liveStatusIndicator" style="font-weight:bold;"></div>
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
        <script src="<%: ResolveUrl("~/Scripts/jquery.signalR-2.4.3.min.js") %>"></script>
        <script src="<%: ResolveUrl("~/signalr/hubs") %>"></script>
        <script type="text/javascript">
            var editor, livePreviewGrid, reportNameTextBox, queryTemplateSelectBox;
            var runLevel1Button, runNextLevelButton, resetLiveSessionButton, updateCurrentLevelButton, prevLevelButton, nextLevelButton;
            var argumentColumnTextBox;
            var chartType = "Bar Chart";
            var chartTypes = [
                { text: "Bar Chart", value: "Bar Chart" },
                { text: "Pie Chart", value: "Pie Chart" },
                { text: "Line Chart", value: "Line Chart" },
                { text: "Table", value: "Table" }
            ];
            var liveSessionData = null;
            var currentEditingLevel = 1;
            var currentReportId = 0;
            var currentTemplateId = null;
            var templateList = [];
            var levelArgumentMap = {};

            require.config({ paths: { 'vs': 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.34.0/min/vs' } });
            require(['vs/editor/editor.main'], function () {
                editor = monaco.editor.create(document.getElementById('monacoEditorContainer'), {
                    value: "SELECT City, SUM(Total) as TotalSales, AVG(Rating) as AverageRating\nFROM AmazonSalesData\nGROUP BY City\nORDER BY TotalSales DESC;",
                    language: 'sql', theme: 'vs-light', automaticLayout: true
                });
            });

            function loadReportsList() {
                $.ajax({
                    type: "POST", url: "Creator.aspx/GetAllReports", contentType: "application/json; charset=utf-8", dataType: "json",
                    success: function (response) {
                        var result = response.d;
                        if (result.Success) {
                            var data = result.Data || [];
                            $("#reportPickerContainer").dxSelectBox({
                                dataSource: data,
                                displayExpr: "ReportName",
                                valueExpr: "ReportID",
                                placeholder: "Pick Report",
                                width: 170,
                                onValueChanged: function (e) { if (e.value) { loadReport(e.value); } }
                            });
                        }
                    }
                });
            }

            function loadReport(reportId) {
                $.ajax({
                    type: "POST", url: "Creator.aspx/GetReportById", contentType: "application/json; charset=utf-8", dataType: "json",
                    data: JSON.stringify({ reportId: reportId }),
                    success: function (response) {
                        var result = response.d;
                        if (result.Success && result.Data) {
                            currentReportId = result.Data.ReportID;
                            reportNameTextBox.option('value', result.Data.ReportName);
                            chartType = result.Data.ChartType || "Bar Chart";
                            $("#chartTypeSelector").dxSelectBox("instance").option("value", chartType);

                            if (result.Data.Levels && result.Data.Levels.length > 0) {
                                resetLiveSession(true);
                                var sessionLevels = [];
                                result.Data.Levels.forEach(function (lvl) {
                                    sessionLevels.push({ Level: lvl.Level, SqlQuery: lvl.SqlQuery, Data: [], Columns: [] });
                                    levelArgumentMap[lvl.Level] = lvl.ArgumentColumnName;
                                });
                                liveSessionData = { _sessionLevels: sessionLevels };
                                navigateLevel(1);
                                updateButtonStates();
                            }
                        }
                    }
                });
            }

            $(function () {
                reportNameTextBox = $('#reportNameTextBox').dxTextBox({ placeholder: 'Report Name' }).dxTextBox('instance');
                argumentColumnTextBox = $('#argumentColumnTextBox').dxTextBox({
                    placeholder: 'Argument Column from Previous Level (e.g., City)'
                }).dxTextBox('instance');

                $('#saveReportButtonContainer').dxButton({ text: 'Save Report', icon: 'save', type: 'success', onClick: saveReport });
                $('#renameReportButtonContainer').dxButton({ text: 'Rename', icon: 'edit', type: 'default', onClick: renameReport });
                $('#deleteReportButtonContainer').dxButton({ text: 'Delete', icon: 'trash', type: 'danger', onClick: deleteReport });

                $("#chartTypeSelector").dxSelectBox({
                    dataSource: chartTypes, displayExpr: "text", valueExpr: "value", value: "Bar Chart",
                    stylingMode: "outlined", onValueChanged: function (e) { chartType = e.value; }
                });

                $('#saveTemplateButtonContainer').dxButton({ text: 'Save Template', icon: 'save', type: 'success', onClick: saveTemplate });
                $('#deleteTemplateButtonContainer').dxButton({ text: 'Delete', icon: 'trash', type: 'danger', onClick: deleteTemplate });
                $('#renameTemplateButtonContainer').dxButton({ text: 'Rename', icon: 'edit', type: 'default', onClick: renameTemplate });

                runLevel1Button = $('#runLevel1Button').dxButton({
                    text: '▶️ Run as Level 1', type: 'default', onClick: function () { runQuery(1, false); }
                }).dxButton('instance');
                runNextLevelButton = $('#runNextLevelButton').dxButton({
                    text: '➡️ Run as Next Level', type: 'normal', disabled: true, onClick: function () { runQuery(getMaxLiveLevel() + 1, false); }
                }).dxButton('instance');
                updateCurrentLevelButton = $('#updateCurrentLevelButton').dxButton({
                    text: '🔄 Update Current Level', type: 'default', icon: 'edit', disabled: true, onClick: function () { runQuery(currentEditingLevel, true); }
                }).dxButton('instance');
                prevLevelButton = $('#prevLevelButton').dxButton({
                    icon: 'chevronleft', disabled: true, text: 'Prev', onClick: function () { navigateLevel(currentEditingLevel - 1); }
                }).dxButton('instance');
                nextLevelButton = $('#nextLevelButton').dxButton({
                    icon: 'chevronright', disabled: true, text: 'Next', onClick: function () { navigateLevel(currentEditingLevel + 1); }
                }).dxButton('instance');
                resetLiveSessionButton = $('#resetLiveSessionButton').dxButton({
                    text: 'Reset Live Session', icon: 'refresh', type: 'danger', disabled: true, onClick: function () { resetLiveSession(false); }
                }).dxButton('instance');

                livePreviewGrid = $('#livePreviewGridContainer').dxDataGrid({
                    dataSource: [], columns: [], showBorders: true, paging: { pageSize: 10 }, columnAutoWidth: true,
                    filterRow: { visible: true }, headerFilter: { visible: true }, searchPanel: { visible: true, width: 240 }
                }).dxDataGrid('instance');

                loadTemplatesList();
                loadReportsList();

                queryTemplateSelectBox = $('#queryTemplateSelectBoxContainer').dxSelectBox({
                    dataSource: templateList, displayExpr: "TemplateName", valueExpr: "TemplateID",
                    placeholder: "Load a template", onOpened: loadTemplatesList,
                    onValueChanged: function (e) { if (e.value) { loadTemplateById(e.value); } }
                }).dxSelectBox('instance');
            });

            function loadTemplatesList() {
                $.ajax({
                    type: "POST", url: "Creator.aspx/GetAllTemplates", contentType: "application/json; charset=utf-8", dataType: "json",
                    success: function (response) {
                        var result = response.d;
                        if (result.Success) {
                            templateList = result.Data || [];
                            $('#queryTemplateSelectBoxContainer').dxSelectBox("instance").option("dataSource", templateList);
                        }
                    }
                });
            }

            function saveTemplate() {
                var templateName = prompt("Template name?");
                var sqlText = editor.getValue();
                if (!templateName || !sqlText) {
                    DevExpress.ui.notify("Template Name and SQL are required.", "error", 2500);
                    return;
                }
                $.ajax({
                    type: "POST", url: "Creator.aspx/SaveQueryTemplate", contentType: "application/json; charset=utf-8", dataType: "json",
                    data: JSON.stringify({ templateName: templateName, sqlQuery: sqlText }),
                    success: function (response) {
                        if (response.d.Success) {
                            DevExpress.ui.notify("Template saved.", "success", 1500);
                            loadTemplatesList();
                        } else {
                            DevExpress.ui.notify(response.d.ErrorMessage, "error", 3500);
                        }
                    }
                });
            }
            function deleteTemplate() {
                var tId = $('#queryTemplateSelectBoxContainer').dxSelectBox("instance").option("value");
                if (!tId) { DevExpress.ui.notify("Select a template to delete.", "error", 1500); return; }
                if (!confirm("Delete selected template?")) return;
                $.ajax({
                    type: "POST", url: "Creator.aspx/DeleteTemplate", contentType: "application/json; charset=utf-8", dataType: "json",
                    data: JSON.stringify({ templateId: tId }),
                    success: function (response) {
                        if (response.d.Success) {
                            DevExpress.ui.notify("Template deleted.", "success", 1500);
                            loadTemplatesList();
                        } else {
                            DevExpress.ui.notify(response.d.ErrorMessage, "error", 3500);
                        }
                    }
                });
            }
            function renameTemplate() {
                var tId = $('#queryTemplateSelectBoxContainer').dxSelectBox("instance").option("value");
                if (!tId) { DevExpress.ui.notify("Select a template to rename.", "error", 1500); return; }
                var newName = prompt("New template name:");
                if (!newName) return;
                $.ajax({
                    type: "POST", url: "Creator.aspx/RenameTemplate", contentType: "application/json; charset=utf-8", dataType: "json",
                    data: JSON.stringify({ templateId: tId, newName: newName }),
                    success: function (response) {
                        if (response.d.Success) {
                            DevExpress.ui.notify("Template renamed.", "success", 1500);
                            loadTemplatesList();
                        } else {
                            DevExpress.ui.notify(response.d.ErrorMessage, "error", 3500);
                        }
                    }
                });
            }
            function loadTemplateById(templateId) {
                $.ajax({
                    type: "POST", url: "Creator.aspx/GetTemplateById", contentType: "application/json; charset=utf-8", dataType: "json",
                    data: JSON.stringify({ templateId: templateId }),
                    success: function (response) {
                        if (response.d.Success && response.d.Data) {
                            editor.setValue(response.d.Data.SQLQuery);
                        }
                    }
                });
            }


            function runQuery(level, isUpdate) {
                if (!editor) return;
                var sqlQuery = editor.getValue();
                if (!sqlQuery) {
                    DevExpress.ui.notify('SQL Query cannot be empty.', 'error', 2000);
                    return;
                }

                if (level > 1) {
                    levelArgumentMap[level] = argumentColumnTextBox.option('value');
                } else {
                    delete levelArgumentMap[level];
                }

                var button = isUpdate ? updateCurrentLevelButton : (level === 1 ? runLevel1Button : runNextLevelButton);
                button.option('disabled', true);
                button.option('text', 'Sending...');

                $.ajax({
                    type: "POST", url: "Creator.aspx/RunLiveQuery", contentType: "application/json; charset=utf-8", dataType: "json",
                    data: JSON.stringify({ sqlQuery: sqlQuery, level: level, isUpdate: isUpdate }),
                    success: function (response) {
                        var result = response.d;
                        if (result.Success) {
                            updateCreatorUI(result.Data);
                            DevExpress.ui.notify('Live Viewer updated!', 'success', 2000);
                        } else {
                            livePreviewGrid.option('dataSource', []);
                            DevExpress.ui.notify('Query Failed: ' + result.ErrorMessage, 'error', 4000);
                        }
                    },
                    error: function () { DevExpress.ui.notify('AJAX error running query.', 'error', 4000); },
                    complete: function () { updateButtonStates(); }
                });
            }

            function resetLiveSession(isSilent) {
                function doReset() {
                    $.ajax({
                        type: "POST", url: "Creator.aspx/ResetLiveSession", contentType: "application/json; charset=utf-8", dataType: "json",
                        success: function (response) {
                            if (response.d.Success) {
                                updateCreatorUI(null);
                                if (!isSilent) DevExpress.ui.notify('Live session has been reset.', 'success', 2000);
                            }
                        }
                    });
                }
                if (isSilent) {
                    doReset();
                } else {
                    DevExpress.ui.dialog.confirm("This will clear the entire live session. Are you sure?", "Confirm Reset").then(function (ok) {
                        if (ok) { doReset(); }
                    });
                }
            }

            function updateCreatorUI(responseData) {
                if (!responseData) {
                    liveSessionData = null;
                    currentEditingLevel = 1;
                    levelArgumentMap = {};
                    livePreviewGrid.option({ 'dataSource': [], 'columns': [] });
                    if (editor) editor.setValue("SELECT City, SUM(Total) as TotalSales, AVG(Rating) as AverageRating\nFROM AmazonSalesData\nGROUP BY City\nORDER BY TotalSales DESC;");
                    argumentColumnTextBox.option('value', '');
                } else {
                    liveSessionData = responseData.FullSession;
                    currentEditingLevel = responseData.CurrentLevel;
                    livePreviewGrid.option('dataSource', responseData.LocalData);
                    livePreviewGrid.option('columns', responseData.LocalData.length > 0 ? Object.keys(responseData.LocalData[0]).map(c => ({ dataField: c, caption: c })) : []);
                }
                updateButtonStates();
            }

            function updateButtonStates() {
                var maxLevel = getMaxLiveLevel();
                runLevel1Button.option({ text: '▶️ Run as Level 1', disabled: false });
                runNextLevelButton.option({ text: '➡️ Run as Next Level', disabled: maxLevel === 0 || maxLevel >= 5 });
                updateCurrentLevelButton.option({ text: '🔄 Update Current Level', disabled: maxLevel === 0 });
                prevLevelButton.option('disabled', currentEditingLevel <= 1);
                nextLevelButton.option('disabled', currentEditingLevel >= maxLevel);
                resetLiveSessionButton.option('disabled', maxLevel === 0);

                if (currentEditingLevel > 1) {
                    argumentColumnTextBox.option('visible', true);
                    argumentColumnTextBox.option('value', levelArgumentMap[currentEditingLevel] || '');
                } else {
                    argumentColumnTextBox.option('visible', false);
                    argumentColumnTextBox.option('value', '');
                }

                $('#liveStatusIndicator').text(maxLevel > 0 ? 'Editing Level: ' + currentEditingLevel + ' / ' + maxLevel : 'No active live session');
            }

            function navigateLevel(targetLevel) {
                if (!liveSessionData || !liveSessionData._sessionLevels) return;

                var levelInfo = liveSessionData._sessionLevels.find(l => l.Level === targetLevel);
                if (levelInfo) {
                    currentEditingLevel = targetLevel;
                    editor.setValue(levelInfo.SqlQuery);
                    livePreviewGrid.option('dataSource', levelInfo.Data);
                    livePreviewGrid.option('columns', (levelInfo.Data && levelInfo.Data.length > 0) ? Object.keys(levelInfo.Data[0]).map(c => ({ dataField: c, caption: c })) : []);
                    updateButtonStates();
                }
            }

            function getMaxLiveLevel() {
                return (liveSessionData && liveSessionData._sessionLevels && liveSessionData._sessionLevels.length > 0)
                    ? Math.max(...liveSessionData._sessionLevels.map(l => l.Level))
                    : 0;
            }

            function saveReport() {
                var reportName = reportNameTextBox.option('value');
                var allLevels = [];
                var sqlQueryToSave = "";

                if (liveSessionData && liveSessionData._sessionLevels && liveSessionData._sessionLevels.length > 0) {
                    liveSessionData._sessionLevels.sort((a, b) => a.Level - b.Level);
                    sqlQueryToSave = liveSessionData._sessionLevels[0].SqlQuery;

                    liveSessionData._sessionLevels.forEach(function (lvl) {
                        var argColName = lvl.Level > 1 ? levelArgumentMap[lvl.Level] : "";
                        allLevels.push({
                            Level: lvl.Level,
                            SqlQuery: lvl.SqlQuery,
                            QueryName: "Level " + lvl.Level,
                            ArgumentColumnName: argColName || ""
                        });
                    });
                } else {
                    sqlQueryToSave = editor.getValue();
                    allLevels.push({ Level: 1, SqlQuery: sqlQueryToSave, QueryName: "Level 1", ArgumentColumnName: "" });
                }

                if (!reportName || !sqlQueryToSave) {
                    DevExpress.ui.notify('Report Name and a valid Level 1 SQL Query are required.', 'error', 3000);
                    return;
                }

                var requestPayload = {
                    ReportId: currentReportId,
                    ReportName: reportName,
                    SQLQuery: sqlQueryToSave,
                    Levels: allLevels
                };

                DevExpress.ui.notify('Saving report...', 'info', 1000);
                $.ajax({
                    type: "POST", url: "Creator.aspx/SaveReport", contentType: "application/json; charset=utf-8", dataType: "json", data: JSON.stringify({ reportData: requestPayload }),
                    success: function (response) {
                        var result = response.d;
                        if (result.Success) {
                            DevExpress.ui.notify('Report saved successfully!', 'success', 3000);
                            currentReportId = result.Data.NewReportId;
                            saveChartTypeAfterReport(currentReportId);
                            loadReportsList();
                        } else { DevExpress.ui.notify('Error saving report: ' + result.ErrorMessage, 'error', 5000); }
                    },
                    error: function () { DevExpress.ui.notify('AJAX error saving report.', 'error', 5000); }
                });
            }

            function saveChartTypeAfterReport(reportId) {
                $.ajax({
                    type: "POST",
                    url: "Creator.aspx/SaveReportChartType",
                    contentType: "application/json; charset=utf-8",
                    dataType: "json",
                    data: JSON.stringify({ reportId: reportId, chartType: chartType }),
                    success: function (response) {
                        if (response.d.Success) {
                            DevExpress.ui.notify("Chart type saved for the report!", "success", 2000);
                        } else {
                            DevExpress.ui.notify("Chart type could not be saved: " + response.d.ErrorMessage, "error", 3500);
                        }
                    }
                });
            }

            function deleteReport() {
                if (!currentReportId) { DevExpress.ui.notify('No report selected.', 'error', 2000); return; }
                if (!confirm("Delete current report?")) return;
                $.ajax({
                    type: "POST", url: "Creator.aspx/DeleteReport", contentType: "application/json; charset=utf-8", dataType: "json",
                    data: JSON.stringify({ reportId: currentReportId }),
                    success: function (response) {
                        var result = response.d;
                        if (result.Success) {
                            DevExpress.ui.notify('Report deleted.', 'success', 1800);
                            currentReportId = 0;
                            reportNameTextBox.option('value', '');
                            editor.setValue('');
                            loadReportsList();
                        } else {
                            DevExpress.ui.notify('Delete failed: ' + result.ErrorMessage, 'error', 3500);
                        }
                    }
                });
            }

            function renameReport() {
                if (!currentReportId) { DevExpress.ui.notify('No report selected.', 'error', 2000); return; }
                var newName = prompt("New report name:");
                if (!newName) return;
                $.ajax({
                    type: "POST", url: "Creator.aspx/RenameReport", contentType: "application/json; charset=utf-8", dataType: "json",
                    data: JSON.stringify({ reportId: currentReportId, newName: newName }),
                    success: function (response) {
                        var result = response.d;
                        if (result.Success) {
                            DevExpress.ui.notify('Report renamed.', 'success', 1500);
                            reportNameTextBox.option('value', newName);
                            loadReportsList();
                        } else {
                            DevExpress.ui.notify('Rename failed: ' + result.ErrorMessage, 'error', 3500);
                        }
                    }
                });
            }
        </script>
    </form>
</body>
</html>
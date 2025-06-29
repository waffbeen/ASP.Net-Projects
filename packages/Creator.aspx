<%@ Page Language="vb" AutoEventWireup="false" CodeBehind="Creator.aspx.vb" Inherits="Vision.Creator" %>

<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>Vision - Data Creator Panel</title>

    <%-- DevExtreme CSS --%>
    <link rel="stylesheet" href="https://cdn3.devexpress.com/jslib/23.2.3/css/dx.common.css" />
    <link rel="stylesheet" href="https://cdn3.devexpress.com/jslib/23.2.3/css/dx.light.css" />

    <%-- Custom CSS --%>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; }
        .container-fluid { width: 95%; margin: 20px auto; }
        #monacoEditorContainer { height: 450px; width: 100%; border: 1px solid #ddd; margin-bottom: 15px; }
        .button-group { display: flex; gap: 10px; margin-top: 10px; }
        #topControls {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            margin-bottom: 15px;
        }
        #promptArea { flex: 1; margin-right: 20px; }
    </style>
</head>
<body>
    <form id="form1" runat="server">
        <div class="container-fluid">
            <h2>📊 Data Creator Panel</h2>

            <div id="topControls">
                <div id="promptArea">
                    <div id="promptTextBoxContainer"></div>
                </div>
                <div id="actionButtons" class="button-group">
                    <div id="enhanceButtonContainer"></div>
                    <div id="runQueryButtonContainer"></div>
                    <div id="saveReportButtonContainer"></div>
                </div>
            </div>

            <div class="button-group">
                <div id="loadTemplateButtonContainer"></div> <%-- New Button --%>
                <div id="saveTemplateButtonContainer"></div> <%-- New Button --%>
                <div id="versionHistoryButtonContainer"></div>
            </div>

            <h4>SQL Query Editor</h4>
            <div id="monacoEditorContainer"></div>

            <h4>Live Data Preview</h4>
            <div id="livePreviewGridContainer"></div>
        </div>

        <%-- Popups --%>
        <div id="saveReportPopupContainer"></div>
        <div id="versionHistoryPopupContainer"></div>
        <div id="loadTemplatePopupContainer"></div> <%-- New Popup --%>
        <div id="saveTemplatePopupContainer"></div> <%-- New Popup --%>

        <%-- JS Libraries --%>
        <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
        <script src="https://cdn3.devexpress.com/jslib/23.2.3/js/dx.all.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/monaco-editor@0.45.0/min/vs/loader.js"></script>

        <script type="text/javascript">
            var editor;
            var saveReportPopup, saveReportForm;
            var versionHistoryPopup;
            var loadTemplatePopup;
            var saveTemplatePopup, saveTemplateForm;
            var currentReportId = 0; // 0 for new report

            // Initialize Monaco Editor
            require.config({ paths: { 'vs': 'https://cdn.jsdelivr.net/npm/monaco-editor@0.45.0/min/vs' } });
            require(['vs/editor/editor.main'], function () {
                editor = monaco.editor.create(document.getElementById('monacoEditorContainer'), {
                    value: 'SELECT TOP 10 * FROM DummySalesTable;',
                    language: 'sql',
                    theme: 'vs-light',
                    automaticLayout: true
                });
            });

            $(function () {
                $('#promptTextBoxContainer').dxTextBox({ placeholder: "Type your query...", showClearButton: true, mode: 'text' });
                $('#enhanceButtonContainer').dxButton({ text: "✨ Enhance Query", onClick: function () { /* Logic here */ } });
                $('#runQueryButtonContainer').dxButton({ text: "▶️ Run Query", type: "success", onClick: function () { /* Logic here */ } });
                $('#livePreviewGridContainer').dxDataGrid({ dataSource: [], showBorders: true, paging: { pageSize: 10 } });
                // ... (Logic for enhance and run query buttons) ...

                // **NEW: Load from Template Button**
                $('#loadTemplateButtonContainer').dxButton({
                    text: "📂 Load from Template",
                    icon: "folder",
                    onClick: function () {
                        if (!loadTemplatePopup) {
                            loadTemplatePopup = $('#loadTemplatePopupContainer').dxPopup({
                                title: "Load Query Template",
                                width: 800,
                                height: 600,
                                showCloseButton: true,
                                contentTemplate: function (contentElement) {
                                    contentElement.append('<div id="loadTemplateGrid"></div>');
                                }
                            }).dxPopup('instance');
                        }
                        loadTemplatePopup.show();
                        loadQueryTemplates();
                    }
                });

                // **NEW: Save as Template Button**
                $('#saveTemplateButtonContainer').dxButton({
                    text: "📝 Save as Template",
                    icon: "save",
                    onClick: function () {
                        if (!saveTemplatePopup) {
                            saveTemplatePopup = $('#saveTemplatePopupContainer').dxPopup({
                                title: "Save New Query Template",
                                width: 500,
                                height: "auto",
                                contentTemplate: function (contentElement) {
                                    contentElement.append('<div id="saveTemplateForm"></div>');
                                    saveTemplateForm = $('#saveTemplateForm').dxForm({
                                        items: [
                                            { dataField: "TemplateName", validationRules: [{ type: "required" }] },
                                            { dataField: "Description", editorType: "dxTextArea" },
                                            {
                                                itemType: "button",
                                                horizontalAlignment: "right",
                                                buttonOptions: {
                                                    text: "Save Template", type: "success",
                                                    onClick: function () {
                                                        var result = saveTemplateForm.validate();
                                                        if (result.isValid) {
                                                            var formData = saveTemplateForm.option("formData");
                                                            formData.SQLQueryTemplate = editor.getValue();

                                                            $.ajax({
                                                                type: "POST", url: "Creator.aspx/SaveQueryTemplate",
                                                                data: JSON.stringify({ templateData: formData }),
                                                                contentType: "application/json; charset=utf-8", dataType: "json",
                                                                success: function (response) {
                                                                    if (response.d.Success) {
                                                                        DevExpress.ui.notify("Template saved successfully!", "success", 3000);
                                                                        saveTemplatePopup.hide();
                                                                    } else {
                                                                        DevExpress.ui.notify("Error: " + response.d.ErrorMessage, "error", 5000);
                                                                    }
                                                                },
                                                                error: function () { DevExpress.ui.notify("AJAX error saving template.", "error", 5000); }
                                                            });
                                                        }
                                                    }
                                                }
                                            }
                                        ]
                                    }).dxForm('instance');
                                }
                            }).dxPopup('instance');
                        }
                        saveTemplateForm.resetValues();
                        saveTemplatePopup.show();
                    }
                });

                // ... (Code for Save Report and Version History buttons remains the same) ...
            });

            // **NEW: Function to load query templates into the popup**
            function loadQueryTemplates() {
                $.ajax({
                    type: "POST",
                    url: "Creator.aspx/GetQueryTemplates",
                    contentType: "application/json; charset=utf-8",
                    dataType: "json",
                    success: function (response) {
                        var result = response.d;
                        if (result.Success) {
                            $('#loadTemplateGrid').dxDataGrid({
                                dataSource: result.Data,
                                columns: [
                                    { dataField: "TemplateName", caption: "Template" },
                                    { dataField: "Description" },
                                    {
                                        type: "buttons",
                                        buttons: [{
                                            hint: "Load this template",
                                            icon: "check",
                                            onClick: function (e) {
                                                var sqlQuery = e.row.data.SQLQueryTemplate;
                                                editor.setValue(sqlQuery);
                                                loadTemplatePopup.hide();
                                                DevExpress.ui.notify("Template '" + e.row.data.TemplateName + "' loaded.", "success", 2000);
                                            }
                                        }]
                                    }
                                ],
                                showBorders: true,
                                paging: { pageSize: 10 },
                                filterRow: { visible: true }
                            });
                        } else {
                            DevExpress.ui.notify("Error loading templates: " + result.ErrorMessage, "error", 3000);
                        }
                    },
                    error: function () {
                        DevExpress.ui.notify("AJAX error loading templates.", "error", 3000);
                    }
                });
            }

            // ... (rest of the JavaScript functions like loadVersionHistory, save report logic, etc.) ...
        </script>
    </form>
</body>
</html>
<%@ Page Language="vb" AutoEventWireup="false" CodeBehind="ManageSQLViews.aspx.vb" Inherits="Vision.ManageSQLViews" %>

<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>Manage SQL Views - Creator Panel</title>
    <%-- DevExtreme CSS --%>
    <link rel="stylesheet" href="https://cdn3.devexpress.com/jslib/23.2.3/css/dx.common.css" />
    <link rel="stylesheet" href="https://cdn3.devexpress.com/jslib/23.2.3/css/dx.light.css" />
    <%-- Monaco Editor CSS --%>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.34.0/min/vs/editor/editor.main.min.css" />
    <style>
        body, html { margin: 0; padding: 0; height: 100%; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; overflow: hidden; }
        body { display: flex; flex-direction: column; }
        
        .navbar { background-color: #343a40; color: white; padding: 10px 20px; display: flex; justify-content: space-between; align-items: center; }
        .navbar a { color: white; text-decoration: none; margin-left: 20px; font-weight: bold; }
        .navbar a:hover { text-decoration: underline; }
        .navbar .user-info { font-size: 0.9em; margin-right: 10px; }

        .page-content { padding: 20px; max-width: 1200px; margin: auto; flex-grow: 1; overflow-y: auto; }
        .dx-fieldset { margin-bottom: 20px; }
        .dx-fieldset-header { font-size: 1.2em; font-weight: bold; margin-bottom: 10px; }
        #sqlEditorContainer { height: 300px; border: 1px solid #ddd; margin-bottom: 15px; }
        #viewsGridContainer { height: 400px; margin-top: 20px; }
    </style>
</head>
<body>
    <form id="form1" runat="server">
        <div class="navbar">
            <div>
                <a href="Viewer.aspx">Viewer Panel</a>
                <span id="creatorPanelLinkContainer" style="display: none;">
                    <a href="Creator.aspx">Creator Panel</a>
                    <a href="ManageSQLViews.aspx">Manage SQL Views</a>
                </span>
            </div>
            <div class="user-info">
                Welcome, <span id="usernameLiteral"></span> (<span id="roleLiteral"></span>)
                <a href="#" onclick="return doLogout();" class="logout-link">Logout</a>
            </div>
        </div>

        <div class="page-content">
            <h1>Manage SQL Views</h1>
            <p>Create, update, or delete SQL Views directly in the database.</p>

            <div class="dx-fieldset">
                <div class="dx-fieldset-header">Create / Edit View</div>
                <div class="dx-field">
                    <div class="dx-field-label">View Name:</div>
                    <div class="dx-field-value" id="viewNameTextBox"></div>
                </div>
                <div class="dx-field">
                    <div class="dx-field-label">SQL Definition:</div>
                    <div class="dx-field-value">
                        <div id="sqlEditorContainer"></div>
                    </div>
                </div>
                <div class="dx-field">
                    <div id="saveViewButton"></div>
                    <div id="clearFormButton" style="margin-left: 10px;"></div>
                    <div id="deleteViewButton" style="margin-left: 10px; display: none;"></div>
                </div>
            </div>

            <div class="dx-fieldset">
                <div class="dx-fieldset-header">Existing Views</div>
                <div id="viewsGridContainer"></div>
            </div>
        </div>

        <%-- ALL JavaScript Libraries are loaded here as this page is now standalone --%>
        <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
        <script src="https://cdn3.devexpress.com/jslib/23.2.3/js/dx.all.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.34.0/min/vs/loader.min.js"></script>
        
        <%-- PDF and Excel Export Libraries (for consistency, though not directly used here) --%>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/FileSaver.js/2.0.5/FileSaver.min.js"></script> 
        <script src="https://cdnjs.cloudflare.com/ajax/libs/exceljs/4.4.0/exceljs.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf-autotable/3.8.2/jspdf.plugin.autotable.min.js"></script>
        
        <script type="text/javascript">
            // DevExtreme requires these global aliases to find the libraries
            if (typeof ExcelJS !== 'undefined') { window.ExcelJS = ExcelJS; }
            if (typeof jspdf !== 'undefined' && typeof jspdf.jsPDF !== 'undefined') { window.jsPDF = jspdf.jsPDF; }

            // Monaco Editor configuration (call require.config only once)
            if (typeof require !== 'undefined' && typeof monaco === 'undefined') {
                require.config({ paths: { 'vs': 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.34.0/min/vs' } });
            }
        </script>

        <script type="text/javascript">
            var editor; // Monaco editor instance
            var viewsGrid;
            var viewNameTextBox; // Global dxTextBox instance
            var currentViewId = null; // Used for editing/deleting existing views

            // Monaco Editor Loader Configuration
            if (typeof require !== 'undefined') {
                require.config({ paths: { 'vs': 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.34.0/min/vs' } });
                require(['vs/editor/editor.main'], function () {
                    editor = monaco.editor.create(document.getElementById('sqlEditorContainer'), {
                        value: 'CREATE VIEW [YourNewViewName] AS\nSELECT\n\t-- Columns\nFROM\n\t-- Tables\nWHERE\n\t-- Conditions',
                        language: 'sql',
                        theme: 'vs-light',
                        automaticLayout: true // Adjusts editor size automatically
                    });
                });
            }


            $(function () {
                // Populate user info from VB.NET Code-behind
                var currentUserRole = '<%= IIF(HttpContext.Current.Session("Role") Is Nothing, String.Empty, HttpContext.Current.Session("Role").ToString()) %>';
                var currentUsername = '<%= IIF(HttpContext.Current.Session("Username") Is Nothing, String.Empty, HttpContext.Current.Session("Username").ToString()) %>';

                $('#usernameLiteral').text(currentUsername || 'Guest');
                $('#roleLiteral').text(currentUserRole || 'None');

                if (currentUserRole === 'Creator') {
                    $('#creatorPanelLinkContainer').show();
                } else {
                    $('#creatorPanelLinkContainer').hide();
                }

                viewNameTextBox = $('#viewNameTextBox').dxTextBox({
                    placeholder: 'Enter SQL View Name',
                    onValueChanged: function (e) {
                        if (editor && !currentViewId) {
                            var currentSql = editor.getValue();
                            var newSql = currentSql.replace(/CREATE VIEW \[.*?\] AS/, `CREATE VIEW [${e.value || 'YourNewViewName'}] AS`);
                            if (currentSql !== newSql) {
                                // editor.setValue(newSql); 
                            }
                        }
                    }
                }).dxTextBox('instance');

                $('#saveViewButton').dxButton({
                    text: 'Save View',
                    icon: 'save',
                    type: 'success',
                    onClick: function () {
                        var viewName = viewNameTextBox.option('value');
                        var sqlDefinition = editor.getValue();

                        if (!viewName || !sqlDefinition) {
                            DevExpress.ui.notify('View Name and SQL Definition are required.', 'error', 3000);
                            return;
                        }

                        var requestPayload = {
                            viewId: currentViewId,
                            viewName: viewName,
                            sqlDefinition: sqlDefinition
                        };

                        DevExpress.ui.notify('Saving view...', 'info', 1000);
                        $.ajax({
                            type: "POST",
                            url: "ManageSQLViews.aspx/SaveSQLView",
                            contentType: "application/json; charset=utf-8",
                            dataType: "json",
                            data: JSON.stringify({ request: requestPayload }),
                            success: function (response) {
                                var result = response.d;
                                if (result.Success) {
                                    DevExpress.ui.notify('View saved successfully!', 'success', 3000);
                                    viewsGrid.getDataSource().reload();
                                    clearForm();
                                } else {
                                    DevExpress.ui.notify('Error saving view: ' + result.ErrorMessage, 'error', 5000);
                                    console.error('Save View Error:', result.ErrorMessage);
                                }
                            },
                            error: function (xhr, status, error) {
                                DevExpress.ui.notify('AJAX error saving view.', 'error', 5000);
                                console.error('AJAX Error:', status, error, xhr);
                            }
                        });
                    }
                });

                $('#clearFormButton').dxButton({
                    text: 'Clear Form',
                    icon: 'clear',
                    type: 'normal',
                    onClick: clearForm
                });

                $('#deleteViewButton').dxButton({
                    text: 'Delete View',
                    icon: 'trash',
                    type: 'danger',
                    visible: false,
                    onClick: function () {
                        if (currentViewId === null) {
                            DevExpress.ui.notify('No view selected for deletion.', 'warning', 2000);
                            return;
                        }

                        DevExpress.ui.dialog.confirm("Are you sure you want to delete this view?", "Confirm Deletion").then(function (dialogResult) {
                            if (dialogResult) {
                                DevExpress.ui.notify('Deleting view...', 'info', 1000);
                                $.ajax({
                                    type: "POST",
                                    url: "ManageSQLViews.aspx/DeleteSQLView",
                                    contentType: "application/json; charset=utf-8",
                                    dataType: "json",
                                    data: JSON.stringify({ viewId: currentViewId }),
                                    success: function (response) {
                                        var result = response.d;
                                        if (result.Success) {
                                            DevExpress.ui.notify('View deleted successfully!', 'success', 3000);
                                            viewsGrid.getDataSource().reload();
                                            clearForm();
                                        } else {
                                            DevExpress.ui.notify('Error deleting view: ' + result.ErrorMessage, 'error', 5000);
                                            console.error('Delete View Error:', result.ErrorMessage);
                                        }
                                    },
                                    error: function (xhr, status, error) {
                                        DevExpress.ui.notify('AJAX error deleting view.', 'error', 5000);
                                        console.error('AJAX Error:', status, error, xhr);
                                    }
                                });
                            }
                        });
                    }
                });

                viewsGrid = $('#viewsGridContainer').dxDataGrid({
                    dataSource: new DevExpress.data.DataSource({
                        load: function () {
                            var d = new $.Deferred();
                            $.ajax({
                                type: "POST",
                                url: "ManageSQLViews.aspx/GetSQLViews",
                                contentType: "application/json; charset=utf-8",
                                dataType: "json",
                                success: function (response) {
                                    var result = response.d;
                                    if (result.Success) {
                                        d.resolve(result.Views || []);
                                    } else {
                                        DevExpress.ui.notify("Error fetching SQL Views: " + result.ErrorMessage, "error", 5000);
                                        d.reject("Server error");
                                    }
                                },
                                error: function (xhr, status, error) {
                                    DevExpress.ui.notify("Network error fetching SQL Views.", "error", 5000);
                                    d.reject("Network error");
                                }
                            });
                            return d.promise();
                        }
                    }),
                    columns: [
                        { dataField: 'ViewName', caption: 'View Name' },
                        { dataField: 'CreatedByUserName', caption: 'Created By' },
                        { dataField: 'CreatedDate', caption: 'Created Date', dataType: 'datetime', format: 'shortDateShortTime' }
                    ],
                    showBorders: true,
                    paging: { pageSize: 10 },
                    filterRow: { visible: true },
                    selection: { mode: 'single' },
                    onSelectionChanged: function (e) {
                        if (e.selectedRowsData.length > 0) {
                            var selectedView = e.selectedRowsData[0];
                            currentViewId = selectedView.ViewID;
                            viewNameTextBox.option('value', selectedView.ViewName);
                            if (editor) {
                                editor.setValue(selectedView.SQLDefinition);
                            }
                            $('#deleteViewButton').dxButton('instance').option('visible', true);
                        } else {
                            clearForm();
                        }
                    }
                }).dxDataGrid('instance');

                function clearForm() {
                    currentViewId = null;
                    viewNameTextBox.option('value', '');
                    if (editor) {
                        editor.setValue('CREATE VIEW [YourNewViewName] AS\nSELECT\n\t-- Columns\nFROM\n\t-- Tables\nWHERE\n\t-- Conditions');
                    }
                    $('#deleteViewButton').dxButton('instance').option('visible', false);
                    viewsGrid.clearSelection();
                }
            });

            // Global Logout Function (defined here as no master page)
            function doLogout() {
                $.ajax({
                    type: "POST",
                    url: "RoleSelector.aspx/Logout", // Call the Logout WebMethod in RoleSelector.aspx.vb
                    contentType: "application/json; charset=utf-8",
                    dataType: "json",
                    success: function (response) {
                        if (response.d.Success) {
                            window.location.href = "RoleSelector.aspx"; // Redirect to role selector page after logout
                        } else {
                            alert("Logout failed: " + response.d.ErrorMessage);
                        }
                    },
                    error: function () {
                        alert("AJAX error during logout.");
                    }
                });
                return false; // Prevent default postback
            }

            // Dynamically set user info in Navbar
            $(document).ready(function () {
                // These variables are assumed to be set by the VB.NET code-behind on Page_Load
                // Example in ManageSQLViews.aspx.vb Page_Load:
                // If Session("UserID") IsNot Nothing Then
                //    Page.ClientScript.RegisterStartupScript(Me.GetType(), "UserInfoVars", _
                //       $"var currentUserID_from_vb = {Session("UserID")};" & _
                //       $"var currentUsername_from_vb = '{Session("Username")?.Replace("'", "\'") || ""}';" & _
                //       $"var currentUserRole_from_vb = '{Session("Role")?.Replace("'", "\'") || ""}';", True)
                // End If

                var currentUserRole = (typeof currentUserRole_from_vb !== 'undefined') ? currentUserRole_from_vb : null;
                var currentUsername = (typeof currentUsername_from_vb !== 'undefined') ? currentUsername_from_vb : 'Guest';

                $('#usernameLiteral').text(currentUsername || 'Guest');
                $('#roleLiteral').text(currentUserRole || 'None');

                if (currentUserRole === 'Creator') {
                    $('#creatorPanelLinkContainer').show();
                } else {
                    $('#creatorPanelLinkContainer').hide();
                }
            });
        </script>
    </form>
</body>
</html>
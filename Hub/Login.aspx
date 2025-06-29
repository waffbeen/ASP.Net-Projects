<%@ Page Language="vb" AutoEventWireup="false" CodeBehind="Login.aspx.vb" Inherits="Vision.Login" %>

<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>Login - Smart Reporting</title>
    <%-- DevExtreme CSS --%>
    <link rel="stylesheet" href="https://cdn3.devexpress.com/jslib/23.2.3/css/dx.common.css" />
    <link rel="stylesheet" href="https://cdn3.devexpress.com/jslib/23.2.3/css/dx.light.css" />
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; display: flex; justify-content: center; align-items: center; min-height: 100vh; background-color: #f0f2f5; }
        .login-container {
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            width: 350px;
            text-align: center;
        }
        .login-container h2 { margin-bottom: 25px; color: #333; }
        .button-group { display: flex; flex-direction: column; gap: 15px; margin-top: 20px; }
        .dx-button { width: 100%; }
    </style>
</head>
<body>
    <form id="form1" runat="server">
        <div class="login-container">
            <h2>📊 Smart Reporting Access</h2>
            <p style="font-size: 0.9em; color: #666;">Choose your role to proceed:</p>
            <div class="button-group">
                <div id="loginAsCreatorButton"></div>
                <div id="loginAsViewerButton"></div>
            </div>
        </div>

        <%-- IMPORTANT: jQuery and DevExtreme JS are loaded here since Login.aspx does NOT use Site.Master --%>
        <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
        <script src="https://cdn3.devexpress.com/jslib/23.2.3/js/dx.all.js"></script>

        <script type="text/javascript">
            var loginForm; // Declare loginForm globally to ensure it's accessible

            $(function () {
                $('#loginAsCreatorButton').dxButton({
                    text: 'Login as Creator (TestUser)',
                    type: 'default',
                    onClick: function () {
                        bypassLogin('Creator');
                    }
                });

                $('#loginAsViewerButton').dxButton({
                    text: 'Login as Viewer (ViewerUser)',
                    type: 'normal',
                    onClick: function () {
                        bypassLogin('Viewer');
                    }
                });

                function bypassLogin(role) {
                    DevExpress.ui.notify('Logging in as ' + role + '...', 'info', 800);
                    $.ajax({
                        type: "POST",
                        url: "Login.aspx/BypassLogin", // New WebMethod
                        contentType: "application/json; charset=utf-8",
                        dataType: "json",
                        data: JSON.stringify({ role: role }), // Send role to backend
                        success: function (response) {
                            var result = response.d;
                            if (result.Success) {
                                DevExpress.ui.notify('Logged in successfully as ' + role + '!', 'success', 1500);
                                setTimeout(function () {
                                    window.location.href = result.RedirectUrl; // Redirect to Creator.aspx or Viewer.aspx
                                }, 1500);
                            } else {
                                DevExpress.ui.notify('Login failed: ' + result.ErrorMessage, 'error', 3000);
                            }
                        },
                        error: function (xhr, status, error) {
                            DevExpress.ui.notify('AJAX error during bypass login.', 'error', 5000);
                            console.error('Bypass Login AJAX Error:', status, error, xhr);
                        }
                    });
                }
            });
        </script>
    </form>
</body>
</html>
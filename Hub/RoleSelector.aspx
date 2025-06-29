<%@ Page Language="vb" AutoEventWireup="false" CodeBehind="RoleSelector.aspx.vb" Inherits="Vision.RoleSelector" %>

<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title>Select Panel - Smart Reporting</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; display: flex; justify-content: center; align-items: center; min-height: 100vh; background-color: #f0f2f5; }
        .selector-container {
            background-color: white;
            padding: 40px;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            width: 400px;
            text-align: center;
        }
        .selector-container h2 { margin-bottom: 25px; color: #333; }
        .button-group { display: flex; flex-direction: column; gap: 15px; margin-top: 20px; }
        .button-link {
            display: inline-block;
            box-sizing: border-box;
            width: 100%;
            padding: 15px 0;
            text-decoration: none;
            color: white;
            background-color: #007bff;
            border: none;
            border-radius: 5px;
            font-size: 16px;
            cursor: pointer;
            transition: background-color 0.3s;
        }
        .button-link:hover {
            background-color: #0056b3;
        }
        .button-link.creator {
            background-color: #28a745;
        }
        .button-link.creator:hover {
            background-color: #218838;
        }
    </style>
</head>
<body>
    <form id="form1" runat="server">
        <div class="selector-container">
            <h2>📊 Smart Reporting Panel</h2>
            <p>Please select which panel you want to open:</p>
            <div class="button-group">
                <a href="Viewer.aspx" class="button-link">Open Viewer Panel</a>
                <a href="Creator.aspx" class="button-link creator">Open Creator Panel</a>
            </div>
        </div>
    </form>
</body>
</html>
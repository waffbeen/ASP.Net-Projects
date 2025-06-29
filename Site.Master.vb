' --- Add these Imports at the very top (no change needed here) ---
' No FormsAuthentication imports needed as it's not used.

Partial Public Class SiteMaster
    Inherits System.Web.UI.MasterPage

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        ' Check if user is logged in based on Session variables only
        If HttpContext.Current.Session("UserID") Is Nothing OrElse HttpContext.Current.Session("Role") Is Nothing Then
            ' If not logged in, redirect to Login.aspx
            ' Only redirect if not already on the login page to prevent infinite loops
            If Not Request.Url.AbsolutePath.ToLower().Contains("login.aspx") Then
                Response.Redirect("~/Login.aspx", False)
            End If
        Else
            ' Display username and role from session
            UsernameLiteral.Text = HttpContext.Current.Session("Username")?.ToString()
            RoleLiteral.Text = HttpContext.Current.Session("Role")?.ToString()

            ' Show Creator panel links only if role is "Creator"
            If HttpContext.Current.Session("Role")?.ToString() = "Creator" Then
                CreatorPanelLink.Visible = True
            Else
                CreatorPanelLink.Visible = False
            End If
        End If
    End Sub

End Class
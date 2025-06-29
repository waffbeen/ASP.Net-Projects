' --- Add these Imports at the very top ---
Imports System.Web.Services
Imports System.Data.SqlClient
Imports System.Configuration
Imports System.Web.Script.Serialization
' REMOVED: System.Security.Cryptography (not used in simplified login)
' REMOVED: System.Text (not used in simplified login)
' REMOVED: System.Web.Security (FormsAuthentication no longer used)

Partial Class Login
    Inherits System.Web.UI.Page

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        ' Check if user is already logged in based on Session variables only
        If Session("UserID") IsNot Nothing AndAlso Session("Role") IsNot Nothing Then
            Dim role As String = HttpContext.Current.Session("Role")?.ToString()
            If role = "Creator" Then
                Response.Redirect("~/Creator.aspx", False)
            Else
                Response.Redirect("~/Viewer.aspx", False)
            End If
            Exit Sub
        End If
    End Sub

    ' DTO for JSON response
    Public Class JsonResponse
        Public Property Success As Boolean
        Public Property ErrorMessage As String
        Public Property RedirectUrl As String
    End Class

    ' NEW: Bypass Login WebMethod - directly sets session based on role
    <WebMethod(EnableSession:=True)>
    Public Shared Function BypassLogin(role As String) As JsonResponse
        Dim response As New JsonResponse()

        Dim userIdToSet As Integer
        Dim usernameToSet As String
        Dim roleToSet As String
        Dim redirectUrl As String

        Select Case role.ToLower()
            Case "creator"
                userIdToSet = 1 ' Hardcoded Creator UserID from sample data
                usernameToSet = "TestUser"
                roleToSet = "Creator"
                redirectUrl = "Creator.aspx"
            Case "viewer"
                userIdToSet = 2 ' Hardcoded Viewer UserID from sample data
                usernameToSet = "ViewerUser"
                roleToSet = "Viewer"
                redirectUrl = "Viewer.aspx"
            Case Else
                response.Success = False
                response.ErrorMessage = "Invalid role specified."
                Return response
        End Select

        Try
            ' This relies solely on Session for simplicity.
            HttpContext.Current.Session("UserID") = userIdToSet
            HttpContext.Current.Session("Role") = roleToSet
            HttpContext.Current.Session("Username") = usernameToSet

            response.Success = True
            response.RedirectUrl = redirectUrl
        Catch ex As Exception
            response.Success = False
            response.ErrorMessage = "Error setting session: " & ex.Message
            System.Diagnostics.Debug.WriteLine("Error in BypassLogin: " & ex.Message & Environment.NewLine & ex.StackTrace)
        End Try
        Return response
    End Function

    ' Basic Logout WebMethod (remains)
    <WebMethod(EnableSession:=True)>
    Public Shared Function Logout() As JsonResponse
        Dim response As New JsonResponse()
        Try
            HttpContext.Current.Session.Clear()
            HttpContext.Current.Session.Abandon()
            response.Success = True
        Catch ex As Exception
            response.Success = False
            response.ErrorMessage = "Error during logout: " & ex.Message
        End Try
        Return response
    End Function

End Class
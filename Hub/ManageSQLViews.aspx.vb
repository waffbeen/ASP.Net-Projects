' --- Add these Imports at the very top ---
Imports System.Web.Services
Imports System.Data.SqlClient
Imports System.Configuration
Imports System.Collections.Generic
Imports System.Web.Script.Serialization
Imports System.Data
Imports System.Text.RegularExpressions

Partial Class ManageSQLViews
    Inherits System.Web.UI.Page

    ' --- Utility Classes for JSON Responses and DTOs ---
    Public Class JsonResponse
        Public Property Success As Boolean
        Public Property ErrorMessage As String
        Public Property Views As List(Of SQLViewInfo) ' For GetSQLViews
    End Class

    ' DTO for SQL View data (from DB to Frontend)
    Public Class SQLViewInfo
        Public Property ViewID As Integer
        Public Property ViewName As String
        Public Property SQLDefinition As String
        Public Property CreatedByUserID As Integer
        Public Property CreatedByUserName As String ' Joined from Users table
        Public Property CreatedDate As DateTime
        Public Property LastModifiedDate As DateTime
    End Class

    ' DTO for Save/Update request from Frontend
    Public Class SaveSQLViewRequest
        Public Property ViewId As Integer? ' Null for new, value for update
        Public Property ViewName As String
        Public Property SQLDefinition As String
    End Class

    ' DTO for Delete request from Frontend
    Public Class DeleteSQLViewRequest
        Public Property ViewId As Integer
    End Class

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        ' भूमिका-विशिष्ट जांच अभी भी यहाँ आवश्यक है।
        If HttpContext.Current.Session("Role")?.ToString() <> "Creator" Then
            Response.Redirect("~/Viewer.aspx", False) ' Redirect non-creators
            Return
        End If
    End Sub

    ' WebMethod to save (create/alter) a SQL View
    <WebMethod(EnableSession:=True)>
    Public Shared Function SaveSQLView(request As SaveSQLViewRequest) As JsonResponse
        Dim response As New JsonResponse()
        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
        Dim currentUserID As Integer
        Dim currentUserIDStr As String = HttpContext.Current.Session("UserID")?.ToString()

        If Not Integer.TryParse(currentUserIDStr, currentUserID) Then
            response.Success = False
            response.ErrorMessage = "Invalid UserID in session. Please log in again."
            Return response
        End If

        If String.IsNullOrWhiteSpace(request.ViewName) OrElse String.IsNullOrWhiteSpace(request.SQLDefinition) Then
            response.Success = False
            response.ErrorMessage = "View Name and SQL Definition are required."
            Return response
        End If

        ' --- SECURITY VALIDATION: Crucial for direct SQL execution ---
        ' Basic validation: Ensure SQL definition starts with CREATE VIEW or ALTER VIEW
        ' And does not contain malicious keywords like DROP, DELETE, INSERT, UPDATE etc.
        Dim cleanedSqlDefinition As String = request.SQLDefinition.Trim()
        Dim viewNamePattern As String = $"\s*(CREATE|ALTER)\s+VIEW\s+(?:\[dbo\]\.)?\[{Regex.Escape(request.ViewName)}\]\s+AS\s+"

        If Not Regex.IsMatch(cleanedSqlDefinition, viewNamePattern, RegexOptions.IgnoreCase) Then
            response.Success = False
            response.ErrorMessage = "SQL Definition must start with 'CREATE VIEW [YourViewName] AS' or 'ALTER VIEW [YourViewName] AS' matching the provided View Name."
            Return response
        End If

        ' Allow SELECT, but prevent other DML/DDL operations not part of the view definition structure
        If Regex.IsMatch(cleanedSqlDefinition, "\b(DROP|DELETE|INSERT|UPDATE|TRUNCATE|EXEC|sp_executesql|xp_cmdshell)\b", RegexOptions.IgnoreCase) AndAlso Not Regex.IsMatch(cleanedSqlDefinition, "\b(SELECT\s+.*?(INSERT|UPDATE|DELETE)\s+FROM)\b", RegexOptions.IgnoreCase) Then
            ' The second regex tries to allow cases like "SELECT ... FROM (INSERT INTO ...)" which might be valid in complex views (though rare).
            ' This is a heuristic. For true security, a robust SQL parser or whitelisting of exact syntax is needed.
            response.Success = False
            response.ErrorMessage = "Potentially malicious SQL keywords detected. Only SELECT statements are generally allowed in view definitions. For advanced usage, contact admin."
            Return response
        End If
        ' --- END SECURITY VALIDATION ---

        Using conn As New SqlConnection(connectionString)
            Try
                conn.Open()
                Dim transaction As SqlTransaction = conn.BeginTransaction()

                Try
                    ' 1. Execute CREATE/ALTER VIEW command directly in DB
                    Using cmdExecView As New SqlCommand(cleanedSqlDefinition, conn, transaction)
                        cmdExecView.CommandTimeout = 60 ' Allow more time for complex views
                        cmdExecView.ExecuteNonQuery()
                    End Using

                    ' 2. Update ManagedSQLViews table with metadata
                    If request.ViewId.HasValue AndAlso request.ViewId.Value > 0 Then
                        ' Update existing view metadata
                        Using cmdUpdateMeta As New SqlCommand("UPDATE ManagedSQLViews SET ViewName = @ViewName, SQLDefinition = @SQLDefinition, LastModifiedDate = GETDATE() WHERE ViewID = @ViewID AND CreatedByUserID = @CreatedByUserID", conn, transaction)
                            cmdUpdateMeta.Parameters.AddWithValue("@ViewID", request.ViewId.Value)
                            cmdUpdateMeta.Parameters.AddWithValue("@ViewName", request.ViewName)
                            cmdUpdateMeta.Parameters.AddWithValue("@SQLDefinition", request.SQLDefinition)
                            cmdUpdateMeta.Parameters.AddWithValue("@CreatedByUserID", currentUserID)
                            cmdUpdateMeta.ExecuteNonQuery()
                        End Using
                    Else
                        ' Insert new view metadata
                        Using cmdInsertMeta As New SqlCommand("INSERT INTO ManagedSQLViews (ViewName, SQLDefinition, CreatedByUserID) VALUES (@ViewName, @SQLDefinition, @CreatedByUserID)", conn, transaction)
                            cmdInsertMeta.Parameters.AddWithValue("@ViewName", request.ViewName)
                            cmdInsertMeta.Parameters.AddWithValue("@SQLDefinition", request.SQLDefinition)
                            cmdInsertMeta.Parameters.AddWithValue("@CreatedByUserID", currentUserID)
                            cmdInsertMeta.ExecuteNonQuery()
                        End Using
                    End If

                    transaction.Commit()
                    response.Success = True

                Catch exTrans As Exception
                    transaction.Rollback()
                    response.Success = False
                    response.ErrorMessage = "Database transaction failed: " & exTrans.Message
                    System.Diagnostics.Debug.WriteLine("Transaction Error in SaveSQLView: " & exTrans.Message & Environment.NewLine & exTrans.StackTrace)
                End Try

            Catch exConn As Exception
                response.Success = False
                response.ErrorMessage = "Database connection error: " & exConn.Message
                System.Diagnostics.Debug.WriteLine("Connection Error in SaveSQLView: " & exConn.Message & Environment.NewLine & exConn.StackTrace)
            End Try
        End Using
        Return response
    End Function

    ' WebMethod to delete a SQL View
    <WebMethod(EnableSession:=True)>
    Public Shared Function DeleteSQLView(request As DeleteSQLViewRequest) As JsonResponse
        Dim response As New JsonResponse()
        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
        Dim currentUserID As Integer
        Dim currentUserIDStr As String = HttpContext.Current.Session("UserID")?.ToString()

        If Not Integer.TryParse(currentUserIDStr, currentUserID) Then
            response.Success = False
            response.ErrorMessage = "Invalid UserID in session. Please log in again."
            Return response
        End If

        Using conn As New SqlConnection(connectionString)
            Try
                conn.Open()
                Dim transaction As SqlTransaction = conn.BeginTransaction()

                Try
                    ' 1. Get View Name from metadata table to use in DROP VIEW command
                    Dim viewName As String = ""
                    Using cmdGetViewName As New SqlCommand("SELECT ViewName FROM ManagedSQLViews WHERE ViewID = @ViewID AND CreatedByUserID = @CreatedByUserID", conn, transaction)
                        cmdGetViewName.Parameters.AddWithValue("@ViewID", request.ViewId)
                        cmdGetViewName.Parameters.AddWithValue("@CreatedByUserID", currentUserID)
                        Dim result As Object = cmdGetViewName.ExecuteScalar()
                        If result IsNot Nothing Then
                            viewName = result.ToString()
                        Else
                            response.Success = False
                            response.ErrorMessage = "View not found or you don't have permission to delete it."
                            Return response
                        End If
                    End Using

                    ' 2. Execute DROP VIEW command directly in DB
                    Using cmdDropView As New SqlCommand($"DROP VIEW [dbo].[{viewName}]", conn, transaction)
                        cmdDropView.ExecuteNonQuery()
                    End Using

                    ' 3. Delete metadata from ManagedSQLViews table
                    Using cmdDeleteMeta As New SqlCommand("DELETE FROM ManagedSQLViews WHERE ViewID = @ViewID AND CreatedByUserID = @CreatedByUserID", conn, transaction)
                        cmdDeleteMeta.Parameters.AddWithValue("@ViewID", request.ViewId)
                        cmdDeleteMeta.Parameters.AddWithValue("@CreatedByUserID", currentUserID)
                        cmdDeleteMeta.ExecuteNonQuery()
                    End Using

                    transaction.Commit()
                    response.Success = True

                Catch exTrans As Exception
                    transaction.Rollback()
                    response.Success = False
                    response.ErrorMessage = "Database transaction failed: " & exTrans.Message
                    System.Diagnostics.Debug.WriteLine("Transaction Error in DeleteSQLView: " & exTrans.Message & Environment.NewLine & exTrans.StackTrace)
                End Try

            Catch exConn As Exception
                response.Success = False
                response.ErrorMessage = "Database connection error: " & exConn.Message
                System.Diagnostics.Debug.WriteLine("Connection Error in DeleteSQLView: " & exConn.Message & Environment.NewLine & exConn.StackTrace)
            End Try
        End Using
        Return response
    End Function

    ' WebMethod to get list of SQL Views
    <WebMethod(EnableSession:=True)>
    Public Shared Function GetSQLViews() As JsonResponse
        Dim response As New JsonResponse()
        Dim views As New List(Of SQLViewInfo)()
        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
        Dim currentUserID As Integer
        Dim currentUserIDStr As String = HttpContext.Current.Session("UserID")?.ToString()

        If Not Integer.TryParse(currentUserIDStr, currentUserID) Then
            response.Success = False
            response.ErrorMessage = "Invalid UserID in session. Please log in again."
            Return response
        End If

        Using conn As New SqlConnection(connectionString)
            Try
                conn.Open()
                Dim sql As String = "SELECT mv.ViewID, mv.ViewName, mv.SQLDefinition, mv.CreatedByUserID, u.Username AS CreatedByUserName, mv.CreatedDate, mv.LastModifiedDate " &
                                    "FROM ManagedSQLViews mv JOIN Users u ON mv.CreatedByUserID = u.UserID " &
                                    "WHERE mv.CreatedByUserID = @UserID ORDER BY mv.ViewName;"

                Using cmd As New SqlCommand(sql, conn)
                    cmd.Parameters.AddWithValue("@UserID", currentUserID)
                    Using reader As SqlDataReader = cmd.ExecuteReader()
                        While reader.Read()
                            views.Add(New SQLViewInfo() With {
                                .ViewID = Convert.ToInt32(reader("ViewID")),
                                .ViewName = reader("ViewName").ToString(),
                                .SQLDefinition = reader("SQLDefinition").ToString(),
                                .CreatedByUserID = Convert.ToInt32(reader("CreatedByUserID")),
                                .CreatedByUserName = reader("CreatedByUserName").ToString(),
                                .CreatedDate = Convert.ToDateTime(reader("CreatedDate")),
                                .LastModifiedDate = Convert.ToDateTime(reader("LastModifiedDate"))
                            })
                        End While
                    End Using
                End Using
                response.Success = True
                response.Views = views
            Catch ex As Exception
                response.Success = False
                response.ErrorMessage = "Error fetching SQL Views: " & ex.Message
                System.Diagnostics.Debug.WriteLine("Error in GetSQLViews: " & ex.Message & Environment.NewLine & ex.StackTrace)
            End Try
        End Using
        Return response
    End Function

End Class
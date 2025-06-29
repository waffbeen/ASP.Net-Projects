Imports System.Web.Services
Imports System.Data.SqlClient
Imports System.Configuration
Imports System.Collections.Generic
Imports System.Web.Script.Serialization
Imports System.Data

Partial Class Creator
    Inherits System.Web.UI.Page

    ' --- Utility Classes for JSON Responses and Data Transfer Objects (DTOs) ---
    Public Class JsonResponse
        Public Property Success As Boolean
        Public Property ErrorMessage As String
        Public Property Data As Object
    End Class

    Public Class ReportSaveDTO
        Public Property ReportId As Integer ' 0 for new, > 0 for existing
        Public Property ReportName As String
        Public Property ReportDescription As String
        Public Property SQLQuery As String
        Public Property AllowedUsersCSV As String
    End Class

    ' NEW DTO for Query Templates
    Public Class QueryTemplateDTO
        Public Property TemplateName As String
        Public Property Description As String
        Public Property SQLQueryTemplate As String
    End Class

    Public Class UserTagInfo
        Public Property UserID As Integer
        Public Property Username As String
    End Class

    Public Class VersionInfo
        Public Property VersionID As Integer
        Public Property SavedDate As String
        Public Property Username As String
        Public Property SQLQuery As String
    End Class


    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Session("UserID") Is Nothing OrElse Session("Role") Is Nothing Then
            Session("UserID") = ConfigurationManager.AppSettings("TestUserID")
            Session("Role") = ConfigurationManager.AppSettings("TestUserRole")
        End If
    End Sub

    ' ... (RunSqlQuery, EnhanceQueryFromPrompt, SaveReport, GetUsersForTagBox, GetReportVersions methods remain the same) ...
    ' WebMethod to execute SQL query and return results for DevExtreme DataGrid
    <WebMethod()>
    Public Shared Function RunSqlQuery(sqlQuery As String) As JsonResponse
        Dim response As New JsonResponse()
        If String.IsNullOrWhiteSpace(sqlQuery) Then
            response.Success = False
            response.ErrorMessage = "SQL query cannot be empty."
            Return response
        End If

        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
        Using conn As New SqlConnection(connectionString)
            Try
                conn.Open()
                Using cmd As New SqlCommand(sqlQuery, conn)
                    If Not sqlQuery.Trim().ToUpper().StartsWith("SELECT") Then
                        response.Success = False
                        response.ErrorMessage = "Only SELECT queries are allowed for live preview."
                        Return response
                    End If
                    Using adapter As New SqlDataAdapter(cmd)
                        Dim dt As New DataTable()
                        adapter.Fill(dt)
                        Dim dataRows As New List(Of Dictionary(Of String, Object))
                        For Each row As DataRow In dt.Rows
                            Dim item As New Dictionary(Of String, Object)()
                            For Each col As DataColumn In dt.Columns
                                item.Add(col.ColumnName, row(col.ColumnName))
                            Next
                            dataRows.Add(item)
                        Next
                        response.Success = True
                        response.Data = dataRows
                    End Using
                End Using
            Catch ex As Exception
                response.Success = False
                response.ErrorMessage = "Database error: " & ex.Message
            End Try
        End Using
        Return response
    End Function

    ' WebMethod for Rule-based Natural Language to SQL conversion
    <WebMethod()>
    Public Shared Function EnhanceQueryFromPrompt(prompt As String) As String
        Dim generatedSql As String = ""
        Dim lowerPrompt As String = prompt.ToLower()
        If lowerPrompt.Contains("sales") AndAlso lowerPrompt.Contains("monthly") Then
            generatedSql = "SELECT FORMAT(OrderDate, 'yyyy-MM') AS Month, SUM(Amount) AS TotalSales FROM DummySalesTable GROUP BY FORMAT(OrderDate, 'yyyy-MM') ORDER BY Month;"
        ElseIf lowerPrompt.Contains("inventory") OrElse lowerPrompt.Contains("products") Then
            generatedSql = "SELECT ProductID, ProductName, StockQuantity FROM DummyProductsTable WHERE StockQuantity < 50 ORDER BY StockQuantity ASC;"
        ElseIf lowerPrompt.Contains("customer") AndAlso lowerPrompt.Contains("orders") Then
            generatedSql = "SELECT CustomerName, OrderID, OrderDate, TotalAmount FROM DummyOrdersTable WHERE CustomerID = 10;"
        Else
            generatedSql = "-- Could not generate SQL based on your input."
        End If
        Return generatedSql
    End Function

    ' UPDATED SaveNewReport WebMethod for Version Control
    <WebMethod()>
    Public Shared Function SaveReport(reportData As ReportSaveDTO) As JsonResponse
        Dim response As New JsonResponse()
        Dim currentUserID As String = HttpContext.Current.Session("UserID")?.ToString()

        If String.IsNullOrWhiteSpace(currentUserID) Then
            response.Success = False : response.ErrorMessage = "User ID not found in session."
            Return response
        End If
        If String.IsNullOrWhiteSpace(reportData.ReportName) OrElse String.IsNullOrWhiteSpace(reportData.SQLQuery) Then
            response.Success = False : response.ErrorMessage = "Report Name and SQL Query cannot be empty."
            Return response
        End If

        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
        Using conn As New SqlConnection(connectionString)
            conn.Open()
            Using tran As SqlTransaction = conn.BeginTransaction()
                Try
                    Dim reportId As Integer = reportData.ReportId

                    If reportId = 0 Then
                        ' INSERT new report and get the new ReportID
                        Dim insertSql As String = "INSERT INTO SavedReports (ReportName, Description, SQLQuery, CreatedBy, AllowedUsers, CreatedDate, LastModified) " &
                                                  "VALUES (@ReportName, @Description, @SQLQuery, @CreatedBy, @AllowedUsers, GETDATE(), GETDATE());" &
                                                  "SELECT SCOPE_IDENTITY();"
                        Using cmd As New SqlCommand(insertSql, conn, tran)
                            cmd.Parameters.AddWithValue("@ReportName", reportData.ReportName)
                            cmd.Parameters.AddWithValue("@Description", If(String.IsNullOrWhiteSpace(reportData.ReportDescription), DBNull.Value, reportData.ReportDescription))
                            cmd.Parameters.AddWithValue("@SQLQuery", reportData.SQLQuery)
                            cmd.Parameters.AddWithValue("@CreatedBy", Integer.Parse(currentUserID))
                            cmd.Parameters.AddWithValue("@AllowedUsers", If(String.IsNullOrWhiteSpace(reportData.AllowedUsersCSV), "", reportData.AllowedUsersCSV))
                            reportId = Convert.ToInt32(cmd.ExecuteScalar())
                        End Using
                    Else
                        ' UPDATE existing report
                        Dim updateSql As String = "UPDATE SavedReports SET " &
                                                  "ReportName = @ReportName, Description = @Description, SQLQuery = @SQLQuery, " &
                                                  "AllowedUsers = @AllowedUsers, LastModified = GETDATE() " &
                                                  "WHERE ReportID = @ReportID;"
                        Using cmd As New SqlCommand(updateSql, conn, tran)
                            cmd.Parameters.AddWithValue("@ReportName", reportData.ReportName)
                            cmd.Parameters.AddWithValue("@Description", If(String.IsNullOrWhiteSpace(reportData.ReportDescription), DBNull.Value, reportData.ReportDescription))
                            cmd.Parameters.AddWithValue("@SQLQuery", reportData.SQLQuery)
                            cmd.Parameters.AddWithValue("@AllowedUsers", If(String.IsNullOrWhiteSpace(reportData.AllowedUsersCSV), "", reportData.AllowedUsersCSV))
                            cmd.Parameters.AddWithValue("@ReportID", reportId)
                            cmd.ExecuteNonQuery()
                        End Using
                    End If

                    ' Add a new version to ReportVersions table for both new reports and updates
                    Dim versionSql As String = "INSERT INTO ReportVersions (ReportID, SQLQuery, SavedBy, SavedDate) " &
                                               "VALUES (@ReportID, @SQLQuery, @SavedBy, GETDATE());"
                    Using cmdVersion As New SqlCommand(versionSql, conn, tran)
                        cmdVersion.Parameters.AddWithValue("@ReportID", reportId)
                        cmdVersion.Parameters.AddWithValue("@SQLQuery", reportData.SQLQuery)
                        cmdVersion.Parameters.AddWithValue("@SavedBy", Integer.Parse(currentUserID))
                        cmdVersion.ExecuteNonQuery()
                    End Using

                    tran.Commit()
                    response.Success = True
                    response.Data = New With {.NewReportId = reportId}

                Catch ex As SqlException
                    tran.Rollback()
                    If ex.Number = 2627 Then
                        response.Success = False
                        response.ErrorMessage = "A report with this name already exists. Please choose a different name."
                    Else
                        response.Success = False
                        response.ErrorMessage = "Database error saving report: " & ex.Message
                    End If
                Catch ex As Exception
                    tran.Rollback()
                    response.Success = False
                    response.ErrorMessage = "Error saving report: " & ex.Message
                End Try
            End Using
        End Using
        Return response
    End Function

    ' WebMethod to get users for the TagBox
    <WebMethod()>
    Public Shared Function GetUsersForTagBox() As JsonResponse
        Dim response As New JsonResponse()
        Dim users As New List(Of UserTagInfo)()
        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
        Using conn As New SqlConnection(connectionString)
            Try
                conn.Open()
                Dim sql As String = "SELECT UserID, Username FROM Users ORDER BY Username;"
                Using cmd As New SqlCommand(sql, conn)
                    Using reader As SqlDataReader = cmd.ExecuteReader()
                        While reader.Read()
                            users.Add(New UserTagInfo() With {
                                .UserID = Convert.ToInt32(reader("UserID")),
                                .Username = reader("Username").ToString()
                            })
                        End While
                    End Using
                End Using
                response.Success = True
                response.Data = users
            Catch ex As Exception
                response.Success = False
                response.ErrorMessage = "Error fetching users for tag box: " & ex.Message
            End Try
        End Using
        Return response
    End Function

    ' WebMethod to get Version History for a report
    <WebMethod()>
    Public Shared Function GetReportVersions(reportId As Integer) As JsonResponse
        Dim response As New JsonResponse()
        Dim versions As New List(Of VersionInfo)()

        If reportId <= 0 Then
            response.Success = False
            response.ErrorMessage = "Invalid Report ID."
            Return response
        End If

        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
        Using conn As New SqlConnection(connectionString)
            Try
                conn.Open()
                Dim sql As String = "SELECT v.VersionID, v.SavedDate, u.Username, v.SQLQuery " &
                                    "FROM ReportVersions v " &
                                    "JOIN Users u ON v.SavedBy = u.UserID " &
                                    "WHERE v.ReportID = @ReportID " &
                                    "ORDER BY v.SavedDate DESC;"
                Using cmd As New SqlCommand(sql, conn)
                    cmd.Parameters.AddWithValue("@ReportID", reportId)
                    Using reader As SqlDataReader = cmd.ExecuteReader()
                        While reader.Read()
                            versions.Add(New VersionInfo() With {
                                .VersionID = Convert.ToInt32(reader("VersionID")),
                                .SavedDate = Convert.ToDateTime(reader("SavedDate")).ToString("g"),
                                .Username = reader("Username").ToString(),
                                .SQLQuery = reader("SQLQuery").ToString()
                            })
                        End While
                    End Using
                End Using
                response.Success = True
                response.Data = versions
            Catch ex As Exception
                response.Success = False
                response.ErrorMessage = "Error fetching version history: " & ex.Message
            End Try
        End Using
        Return response
    End Function

    ' **NEW: WebMethod to Save a new Query Template**
    <WebMethod()>
    Public Shared Function SaveQueryTemplate(templateData As QueryTemplateDTO) As JsonResponse
        Dim response As New JsonResponse()
        Dim currentUserID As String = HttpContext.Current.Session("UserID")?.ToString()

        If String.IsNullOrWhiteSpace(currentUserID) Then
            response.Success = False : response.ErrorMessage = "User ID not found in session."
            Return response
        End If
        If String.IsNullOrWhiteSpace(templateData.TemplateName) OrElse String.IsNullOrWhiteSpace(templateData.SQLQueryTemplate) Then
            response.Success = False : response.ErrorMessage = "Template Name and SQL Query cannot be empty."
            Return response
        End If

        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
        Using conn As New SqlConnection(connectionString)
            Try
                conn.Open()
                Dim sql As String = "INSERT INTO QueryTemplates (TemplateName, Description, SQLQueryTemplate, CreatedBy, CreatedDate) " &
                                    "VALUES (@TemplateName, @Description, @SQLQueryTemplate, @CreatedBy, GETDATE());"
                Using cmd As New SqlCommand(sql, conn)
                    cmd.Parameters.AddWithValue("@TemplateName", templateData.TemplateName)
                    cmd.Parameters.AddWithValue("@Description", If(String.IsNullOrWhiteSpace(templateData.Description), DBNull.Value, templateData.Description))
                    cmd.Parameters.AddWithValue("@SQLQueryTemplate", templateData.SQLQueryTemplate)
                    cmd.Parameters.AddWithValue("@CreatedBy", Integer.Parse(currentUserID))
                    cmd.ExecuteNonQuery()
                    response.Success = True
                End Using
            Catch ex As SqlException
                If ex.Number = 2627 Then ' Unique constraint violation
                    response.Success = False
                    response.ErrorMessage = "A template with this name already exists."
                Else
                    response.Success = False
                    response.ErrorMessage = "Database error saving template: " & ex.Message
                End If
            Catch ex As Exception
                response.Success = False
                response.ErrorMessage = "Error saving template: " & ex.Message
            End Try
        End Using
        Return response
    End Function

    ' **NEW: WebMethod to Get all Query Templates**
    <WebMethod()>
    Public Shared Function GetQueryTemplates() As JsonResponse
        Dim response As New JsonResponse()
        Dim templates As New List(Of Object)()
        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
        Using conn As New SqlConnection(connectionString)
            Try
                conn.Open()
                Dim sql As String = "SELECT TemplateID, TemplateName, Description, SQLQueryTemplate FROM QueryTemplates ORDER BY TemplateName;"
                Using cmd As New SqlCommand(sql, conn)
                    Using reader As SqlDataReader = cmd.ExecuteReader()
                        While reader.Read()
                            templates.Add(New With {
                                .TemplateID = Convert.ToInt32(reader("TemplateID")),
                                .TemplateName = reader("TemplateName").ToString(),
                                .Description = reader("Description").ToString(),
                                .SQLQueryTemplate = reader("SQLQueryTemplate").ToString()
                            })
                        End While
                    End Using
                End Using
                response.Success = True
                response.Data = templates
            Catch ex As Exception
                response.Success = False
                response.ErrorMessage = "Error fetching query templates: " & ex.Message
            End Try
        End Using
        Return response
    End Function

End Class
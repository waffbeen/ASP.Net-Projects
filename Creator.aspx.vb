Imports System.Web.Services
Imports System.Data.SqlClient
Imports System.Configuration
Imports System.Collections.Generic
Imports System.Web.Script.Serialization
Imports System.Data
Imports System.Linq
Imports System.Web
Imports System.Diagnostics

Partial Class Creator
    Inherits System.Web.UI.Page

    Public Class JsonResponse
        Public Property Success As Boolean
        Public Property ErrorMessage As String
        Public Property Data As Object
    End Class

    ' DTO structure for saving a report
    Public Class ReportSaveDTO
        Public Property ReportId As Integer
        Public Property ReportName As String
        Public Property ReportDescription As String ' Added back
        Public Property SQLQuery As String
        Public Property ChartType As String
        Public Property AllowedUsersCSV As String ' Added back
    End Class

    Public Class QueryTemplateDTO
        Public Property TemplateID As Integer
        Public Property TemplateName As String
        Public Property Description As String
        Public Property SQLQueryTemplate As String
    End Class

    Public Class ReportVersionsDTO
        Public Property VersionID As Integer
        Public Property SavedDate As String
        Public Property Username As String
        Public Property SQLQuery As String
    End Class

    Public Class ReportInfoForList
        Public Property ReportID As Integer
        Public Property ReportName As String
    End Class

    ' DTO for loading specific Report Details
    Public Class ReportDetailsDTO
        Public Property ReportID As Integer
        Public Property ReportName As String
        Public Property ReportDescription As String ' Added back
        Public Property SQLQuery As String
        Public Property ChartType As String
        Public Property AllowedUsersCSV As String ' Added back
    End Class


    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Session("UserID") Is Nothing OrElse Session("Role") Is Nothing Then
            Dim testUserId = ConfigurationManager.AppSettings("TestUserID")
            Dim testUserRole = ConfigurationManager.AppSettings("TestUserRole")

            If Integer.TryParse(testUserId, Nothing) Then
                Session("UserID") = testUserId
                Session("Role") = testUserRole
                System.Diagnostics.Debug.WriteLine($"DEBUG: Test user session created. UserID: {Session("UserID")}, Role: {Session("Role")}")
            Else
                System.Diagnostics.Debug.WriteLine("ERROR: TestUserID in Web.config is not a valid integer. Please check appSettings.")
            End If
        End If
    End Sub

    <WebMethod(EnableSession:=True)>
    Public Shared Function RunPreviewQuery(sqlQuery As String) As JsonResponse
        Dim response As New JsonResponse()

        If String.IsNullOrWhiteSpace(sqlQuery) Then
            response.Success = False : response.ErrorMessage = "SQL query cannot be empty."
            Return response
        End If

        If Not sqlQuery.Trim().ToUpper().StartsWith("SELECT", StringComparison.OrdinalIgnoreCase) Then
            response.Success = False : response.ErrorMessage = "Only SELECT queries are allowed for preview."
            Return response
        End If

        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString

        Using conn As New SqlConnection(connectionString)
            Try
                conn.Open()
                Using cmd As New SqlCommand(sqlQuery, conn)
                    Using adapter As New SqlDataAdapter(cmd)
                        Dim dt As New DataTable()
                        adapter.Fill(dt)

                        Dim dataRows = New List(Of Dictionary(Of String, Object))()
                        Dim columns = New List(Of String)()

                        For Each col As DataColumn In dt.Columns
                            columns.Add(col.ColumnName)
                        Next

                        For Each row As DataRow In dt.Rows
                            Dim item As New Dictionary(Of String, Object)()
                            For Each colName As String In columns
                                item.Add(colName, If(row(colName) Is DBNull.Value, Nothing, row(colName)))
                            Next
                            dataRows.Add(item)
                        Next

                        response.Success = True
                        response.Data = New With {
                            .LocalData = dataRows,
                            .Columns = columns
                        }
                    End Using
                End Using
            Catch ex As Exception
                response.Success = False : response.ErrorMessage = "Database error: " & ex.Message
                System.Diagnostics.Debug.WriteLine($"Error in RunPreviewQuery: {ex.Message}{Environment.NewLine}{ex.StackTrace}")
            End Try
        End Using
        Return response
    End Function


    <WebMethod(EnableSession:=True)>
    Public Shared Function SaveReport(reportData As ReportSaveDTO) As JsonResponse
        Dim response As New JsonResponse()
        Dim currentUserIDStr As String = HttpContext.Current.Session("UserID")?.ToString()

        If String.IsNullOrWhiteSpace(currentUserIDStr) Then
            response.Success = False : response.ErrorMessage = "User ID not found in session."
            Return response
        End If
        Dim currentUserID As Integer
        If Not Integer.TryParse(currentUserIDStr, currentUserID) Then
            response.Success = False : response.ErrorMessage = "Invalid User ID in session."
            Return response
        End If

        If String.IsNullOrWhiteSpace(reportData.ReportName) OrElse String.IsNullOrWhiteSpace(reportData.SQLQuery) OrElse String.IsNullOrWhiteSpace(reportData.AllowedUsersCSV) Then
            response.Success = False : response.ErrorMessage = "Report Name, SQL Query, and Allowed Users are required."
            Return response
        End If

        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
        Using conn As New SqlConnection(connectionString)
            conn.Open()
            Using tran As SqlTransaction = conn.BeginTransaction()
                Try
                    Dim reportId As Integer = reportData.ReportId

                    If reportId = 0 Then
                        ' Insert new report
                        Dim insertSql As String = "INSERT INTO SavedReports (ReportName, ReportDescription, SQLQuery, DefaultChartType, CreatedBy, CreatedDate, LastModified, AllowedUsers, IsNew) " &
                                              "VALUES (@ReportName, @ReportDescription, @SQLQuery, @ChartType, @CreatedBy, GETDATE(), GETDATE(), @AllowedUsers, @IsNew); SELECT SCOPE_IDENTITY();"
                        Using cmd As New SqlCommand(insertSql, conn, tran)
                            cmd.Parameters.AddWithValue("@ReportName", reportData.ReportName)
                            cmd.Parameters.AddWithValue("@ReportDescription", If(String.IsNullOrWhiteSpace(reportData.ReportDescription), DBNull.Value, reportData.ReportDescription))
                            cmd.Parameters.AddWithValue("@SQLQuery", reportData.SQLQuery)
                            cmd.Parameters.AddWithValue("@ChartType", If(String.IsNullOrWhiteSpace(reportData.ChartType), DBNull.Value, reportData.ChartType))
                            cmd.Parameters.AddWithValue("@CreatedBy", currentUserID)
                            cmd.Parameters.AddWithValue("@AllowedUsers", If(String.IsNullOrWhiteSpace(reportData.AllowedUsersCSV), DBNull.Value, reportData.AllowedUsersCSV))
                            cmd.Parameters.AddWithValue("@IsNew", True)
                            reportId = Convert.ToInt32(cmd.ExecuteScalar())
                        End Using
                    Else
                        ' Update existing report
                        Dim updateSql As String = "UPDATE SavedReports SET ReportName = @ReportName, ReportDescription = @ReportDescription, SQLQuery = @SQLQuery, DefaultChartType = @ChartType, LastModified = GETDATE(), AllowedUsers = @AllowedUsers, IsNew = 0 " &
                                                  "WHERE ReportID = @ReportID;"
                        Using cmd As New SqlCommand(updateSql, conn, tran)
                            cmd.Parameters.AddWithValue("@ReportName", reportData.ReportName)
                            cmd.Parameters.AddWithValue("@ReportDescription", If(String.IsNullOrWhiteSpace(reportData.ReportDescription), DBNull.Value, reportData.ReportDescription))
                            cmd.Parameters.AddWithValue("@SQLQuery", reportData.SQLQuery)
                            cmd.Parameters.AddWithValue("@ChartType", If(String.IsNullOrWhiteSpace(reportData.ChartType), DBNull.Value, reportData.ChartType))
                            cmd.Parameters.AddWithValue("@AllowedUsers", If(String.IsNullOrWhiteSpace(reportData.AllowedUsersCSV), DBNull.Value, reportData.AllowedUsersCSV))
                            cmd.Parameters.AddWithValue("@ReportID", reportId)
                            cmd.ExecuteNonQuery()
                        End Using
                    End If

                    ' Add a version history entry
                    Dim versionSql As String = "INSERT INTO ReportVersions (ReportID, SQLQuery, SavedBy, SavedDate) VALUES (@ReportID, @SQLQuery, @SavedBy, GETDATE());"
                    Using cmdVersion As New SqlCommand(versionSql, conn, tran)
                        cmdVersion.Parameters.AddWithValue("@ReportID", reportId)
                        cmdVersion.Parameters.AddWithValue("@SQLQuery", reportData.SQLQuery)
                        cmdVersion.Parameters.AddWithValue("@SavedBy", currentUserID)
                        cmdVersion.ExecuteNonQuery()
                    End Using

                    tran.Commit()
                    response.Success = True
                    response.Data = New With {.NewReportId = reportId}
                Catch ex As SqlException
                    tran.Rollback()
                    If ex.Number = 2627 Then
                        response.Success = False : response.ErrorMessage = "A report with this name already exists."
                    Else
                        response.Success = False : response.ErrorMessage = "Database error saving report: " & ex.Message
                    End If
                    System.Diagnostics.Debug.WriteLine($"SQL Error in SaveReport: {ex.Message}{Environment.NewLine}{ex.StackTrace}")
                Catch ex As Exception
                    tran.Rollback()
                    response.Success = False : response.ErrorMessage = "Error saving report: " & ex.Message
                    System.Diagnostics.Debug.WriteLine($"Error in SaveReport: {ex.Message}{Environment.NewLine}{ex.StackTrace}")
                End Try
            End Using
        End Using
        Return response
    End Function


    <WebMethod(EnableSession:=True)>
    Public Shared Function GetReportVersions(reportId As Integer) As JsonResponse
        Dim response As New JsonResponse()
        Dim versions As New List(Of ReportVersionsDTO)()
        If reportId <= 0 Then
            response.Success = False : response.ErrorMessage = "Invalid Report ID."
            Return response
        End If
        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
        Using conn As New SqlConnection(connectionString)
            Try
                conn.Open()
                Dim sql As String = "SELECT v.VersionID, v.SavedDate, u.Username, v.SQLQuery FROM ReportVersions v JOIN Users u ON v.SavedBy = u.UserID WHERE v.ReportID = @ReportID ORDER BY v.SavedDate DESC;"
                Using cmd As New SqlCommand(sql, conn)
                    cmd.Parameters.AddWithValue("@ReportID", reportId)
                    Using reader As SqlDataReader = cmd.ExecuteReader()
                        While reader.Read()
                            versions.Add(New ReportVersionsDTO() With {
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
                response.Success = False : response.ErrorMessage = "Error fetching version history: " & ex.Message
                System.Diagnostics.Debug.WriteLine($"Error in GetReportVersions: {ex.Message}{Environment.NewLine}{ex.StackTrace}")
            End Try
        End Using
        Return response
    End Function


    <WebMethod(EnableSession:=True)>
    Public Shared Function SaveQueryTemplate(templateData As QueryTemplateDTO) As JsonResponse
        Dim response As New JsonResponse()
        Dim currentUserIDStr As String = HttpContext.Current.Session("UserID")?.ToString()
        If String.IsNullOrWhiteSpace(currentUserIDStr) Then
            response.Success = False : response.ErrorMessage = "User ID not found in session."
            Return response
        End If
        Dim currentUserID As Integer
        If Not Integer.TryParse(currentUserIDStr, currentUserID) Then
            response.Success = False : response.ErrorMessage = "Invalid User ID in session."
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
                If templateData.TemplateID > 0 Then
                    Dim updateSql As String = "UPDATE QueryTemplates SET TemplateName = @TemplateName, Description = @Description, SQLQueryTemplate = @SQLQueryTemplate WHERE TemplateID = @TemplateID;"
                    Using cmd As New SqlCommand(updateSql, conn)
                        cmd.Parameters.AddWithValue("@TemplateName", templateData.TemplateName)
                        cmd.Parameters.AddWithValue("@Description", If(String.IsNullOrWhiteSpace(templateData.Description), DBNull.Value, templateData.Description))
                        cmd.Parameters.AddWithValue("@SQLQueryTemplate", templateData.SQLQueryTemplate)
                        cmd.Parameters.AddWithValue("@TemplateID", templateData.TemplateID)
                        If cmd.ExecuteNonQuery() > 0 Then
                            response.Success = True
                        Else
                            response.Success = False : response.ErrorMessage = "Template not found or could not be updated."
                        End If
                    End Using
                Else
                    Dim sql As String = "INSERT INTO QueryTemplates (TemplateName, Description, SQLQueryTemplate, CreatedBy, CreatedDate) VALUES (@TemplateName, @Description, @SQLQueryTemplate, @CreatedBy, GETDATE()); SELECT SCOPE_IDENTITY();"
                    Using cmd As New SqlCommand(sql, conn)
                        cmd.Parameters.AddWithValue("@TemplateName", templateData.TemplateName)
                        cmd.Parameters.AddWithValue("@Description", If(String.IsNullOrWhiteSpace(templateData.Description), DBNull.Value, templateData.Description))
                        cmd.Parameters.AddWithValue("@SQLQueryTemplate", templateData.SQLQueryTemplate)
                        cmd.Parameters.AddWithValue("@CreatedBy", currentUserID)
                        Dim newTemplateId = Convert.ToInt32(cmd.ExecuteScalar())
                        response.Success = True
                        response.Data = New With {.NewTemplateID = newTemplateId}
                    End Using
                End If

            Catch ex As SqlException
                If ex.Number = 2627 Then
                    response.Success = False : response.ErrorMessage = "A template with this name already exists."
                Else
                    response.Success = False : response.ErrorMessage = "Database error saving template: " & ex.Message
                End If
                System.Diagnostics.Debug.WriteLine($"SQL Error in SaveQueryTemplate: {ex.Message}{Environment.NewLine}{ex.StackTrace}")
            Catch ex As Exception
                response.Success = False : response.ErrorMessage = "Error saving template: " & ex.Message
                System.Diagnostics.Debug.WriteLine($"Error in SaveQueryTemplate: {ex.Message}{Environment.NewLine}{ex.StackTrace}")
            End Try
        End Using
        Return response
    End Function

    <WebMethod()>
    Public Shared Function GetAllTemplates() As JsonResponse
        Dim response As New JsonResponse()
        Dim templates As New List(Of QueryTemplateDTO)()
        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
        Using conn As New SqlConnection(connectionString)
            Try
                conn.Open()
                Dim sql As String = "SELECT TemplateID, TemplateName, Description, SQLQueryTemplate FROM QueryTemplates ORDER BY TemplateName;"
                Using cmd As New SqlCommand(sql, conn)
                    Using reader As SqlDataReader = cmd.ExecuteReader()
                        While reader.Read()
                            templates.Add(New QueryTemplateDTO() With {
                                .TemplateID = Convert.ToInt32(reader("TemplateID")),
                                .TemplateName = reader("TemplateName").ToString(),
                                .Description = If(reader("Description") Is DBNull.Value, Nothing, reader("Description").ToString()),
                                .SQLQueryTemplate = reader("SQLQueryTemplate").ToString()
                            })
                        End While
                    End Using
                End Using
                response.Success = True
                response.Data = templates
            Catch ex As Exception
                response.Success = False : response.ErrorMessage = "Error fetching query templates: " & ex.Message
                System.Diagnostics.Debug.WriteLine($"Error in GetAllTemplates: {ex.Message}{Environment.NewLine}{ex.StackTrace}")
            End Try
        End Using
        Return response
    End Function

    <WebMethod()>
    Public Shared Function GetTemplateById(templateId As Integer) As JsonResponse
        Dim response As New JsonResponse()
        If templateId <= 0 Then
            response.Success = False : response.ErrorMessage = "Invalid Template ID."
            Return response
        End If
        Try
            Dim connStr = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
            Using conn As New SqlConnection(connStr)
                conn.Open()
                Dim cmd As New SqlCommand("SELECT TemplateID, TemplateName, Description, SQLQueryTemplate FROM QueryTemplates WHERE TemplateID = @TemplateID", conn)
                cmd.Parameters.AddWithValue("@TemplateID", templateId)
                Using reader = cmd.ExecuteReader()
                    If reader.Read() Then
                        response.Success = True
                        response.Data = New QueryTemplateDTO() With {
                           .TemplateID = Convert.ToInt32(reader("TemplateID")),
                           .TemplateName = reader("TemplateName").ToString(),
                           .Description = If(reader("Description") Is DBNull.Value, Nothing, reader("Description").ToString()),
                           .SQLQueryTemplate = reader("SQLQueryTemplate").ToString()
                        }
                    Else
                        response.Success = False
                        response.ErrorMessage = "Template not found."
                    End If
                End Using
            End Using
        Catch ex As Exception
            response.Success = False
            response.ErrorMessage = "Error loading template: " & ex.Message
            System.Diagnostics.Debug.WriteLine($"Error in GetTemplateById: {ex.Message}{Environment.NewLine}{ex.StackTrace}")
        End Try
        Return response
    End Function


    <WebMethod()>
    Public Shared Function GetReportById(reportId As Integer) As JsonResponse
        Dim response As New JsonResponse()
        If reportId <= 0 Then
            response.Success = False : response.ErrorMessage = "Invalid Report ID."
            Return response
        End If
        Try
            Dim connStr = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
            Using conn As New SqlConnection(connStr)
                conn.Open()
                Dim reportData As New ReportDetailsDTO()

                ' Select all report details, including new columns
                Dim cmd As New SqlCommand("SELECT ReportID, ReportName, ISNULL(ReportDescription,'') AS ReportDescription, ISNULL(DefaultChartType,'GoogleBar') AS ChartType, SQLQuery, ISNULL(AllowedUsers,'') AS AllowedUsers FROM SavedReports WHERE ReportID = @ReportID", conn)
                cmd.Parameters.AddWithValue("@ReportID", reportId)
                Using reader = cmd.ExecuteReader()
                    If reader.Read() Then
                        reportData.ReportID = Convert.ToInt32(reader("ReportID"))
                        reportData.ReportName = reader("ReportName").ToString()
                        reportData.ReportDescription = reader("ReportDescription").ToString()
                        reportData.ChartType = reader("ChartType").ToString()
                        reportData.SQLQuery = reader("SQLQuery").ToString()
                        reportData.AllowedUsersCSV = reader("AllowedUsers").ToString()
                    Else
                        response.Success = False
                        response.ErrorMessage = "Report not found."
                        Return response
                    End If
                End Using
                response.Success = True
                response.Data = reportData
            End Using
        Catch ex As Exception
            response.Success = False
            response.ErrorMessage = "Error loading report: " & ex.Message
            System.Diagnostics.Debug.WriteLine($"Error in GetReportById: {ex.Message}{Environment.NewLine}{ex.StackTrace}")
        End Try
        Return response
    End Function

    <WebMethod()>
    Public Shared Function DeleteReport(reportId As Integer) As JsonResponse
        Dim response As New JsonResponse()
        If reportId <= 0 Then
            response.Success = False : response.ErrorMessage = "Invalid Report ID."
            Return response
        End If
        Try
            Dim connStr = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
            Using conn As New SqlConnection(connStr)
                conn.Open()
                Using tran As SqlTransaction = conn.BeginTransaction()
                    Try
                        Dim cmdDelViews As New SqlCommand("DELETE FROM SavedViews WHERE ReportID=@ReportID", conn, tran)
                        cmdDelViews.Parameters.AddWithValue("@ReportID", reportId)
                        cmdDelViews.ExecuteNonQuery()

                        Dim cmdDelVersions As New SqlCommand("DELETE FROM ReportVersions WHERE ReportID=@ReportID", conn, tran)
                        cmdDelVersions.Parameters.AddWithValue("@ReportID", reportId)
                        cmdDelVersions.ExecuteNonQuery()

                        Dim cmdDelDrillLevels As New SqlCommand("DELETE FROM DrillDownQueries WHERE ReportID=@ReportID", conn, tran)
                        cmdDelDrillLevels.Parameters.AddWithValue("@ReportID", reportId)
                        cmdDelDrillLevels.ExecuteNonQuery()

                        Dim cmdDel As New SqlCommand("DELETE FROM SavedReports WHERE ReportID=@ReportID", conn, tran)
                        cmdDel.Parameters.AddWithValue("@ReportID", reportId)

                        If cmdDel.ExecuteNonQuery() > 0 Then
                            tran.Commit()
                            response.Success = True
                        Else
                            tran.Rollback()
                            response.Success = False
                            response.ErrorMessage = "Report not found."
                        End If
                    Catch ex As Exception
                        tran.Rollback()
                        Throw ex
                    End Try
                End Using
            End Using
        Catch ex As Exception
            response.Success = False
            response.ErrorMessage = "Error deleting report: " & ex.Message
            System.Diagnostics.Debug.WriteLine($"Error in DeleteReport: {ex.Message}{Environment.NewLine}{ex.StackTrace}")
        End Try
        Return response
    End Function

    <WebMethod()>
    Public Shared Function RenameReport(reportId As Integer, newName As String) As JsonResponse
        Dim response As New JsonResponse()
        If String.IsNullOrWhiteSpace(newName) Then
            response.Success = False : response.ErrorMessage = "New name cannot be empty."
            Return response
        End If
        If reportId <= 0 Then
            response.Success = False : response.ErrorMessage = "Invalid Report ID."
            Return response
        End If
        Try
            Dim connStr = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
            Using conn As New SqlConnection(connStr)
                conn.Open()
                Dim cmd As New SqlCommand("UPDATE SavedReports SET ReportName=@Name, LastModified = GETDATE() WHERE ReportID=@ID", conn)
                cmd.Parameters.AddWithValue("@ID", reportId)
                cmd.Parameters.AddWithValue("@Name", newName)
                If cmd.ExecuteNonQuery() > 0 Then
                    response.Success = True
                Else
                    response.Success = False
                    response.ErrorMessage = "Report not found."
                End If
            End Using
        Catch ex As SqlException
            If ex.Number = 2627 Then
                response.Success = False : response.ErrorMessage = "A report with this name already exists."
            Else
                response.Success = False : response.ErrorMessage = "Database error renaming report: " & ex.Message
            End If
            System.Diagnostics.Debug.WriteLine($"SQL Error in RenameReport: {ex.Message}{Environment.NewLine}{ex.StackTrace}")
        Catch ex As Exception
            response.Success = False
            response.ErrorMessage = "Error renaming report: " & ex.Message
            System.Diagnostics.Debug.WriteLine($"Error in RenameReport: {ex.Message}{Environment.NewLine}{ex.StackTrace}")
        End Try
        Return response
    End Function

    <WebMethod()>
    Public Shared Function DeleteQueryTemplate(templateId As Integer) As JsonResponse
        Dim response As New JsonResponse()
        If templateId <= 0 Then
            response.Success = False : response.ErrorMessage = "Invalid Template ID."
            Return response
        End If
        Try
            Dim connStr = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
            Using conn As New SqlConnection(connStr)
                conn.Open()
                Dim cmd As New SqlCommand("DELETE FROM QueryTemplates WHERE TemplateID=@ID", conn)
                cmd.Parameters.AddWithValue("@ID", templateId)
                If cmd.ExecuteNonQuery() > 0 Then
                    response.Success = True
                Else
                    response.Success = False
                    response.ErrorMessage = "Template not found."
                End If
            End Using
        Catch ex As Exception
            response.Success = False
            response.ErrorMessage = "Error deleting template: " & ex.Message
            System.Diagnostics.Debug.WriteLine($"Error in DeleteQueryTemplate: {ex.Message}{Environment.NewLine}{ex.StackTrace}")
        End Try
        Return response
    End Function

    <WebMethod()>
    Public Shared Function RenameQueryTemplate(templateId As Integer, newName As String) As JsonResponse
        Dim response As New JsonResponse()
        If String.IsNullOrWhiteSpace(newName) Then
            response.Success = False : response.ErrorMessage = "New name cannot be empty."
            Return response
        End If
        If templateId <= 0 Then
            response.Success = False : response.ErrorMessage = "Invalid Template ID."
            Return response
        End If
        Try
            Dim connStr = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
            Using conn As New SqlConnection(connStr)
                conn.Open()
                Dim cmd As New SqlCommand("UPDATE QueryTemplates SET TemplateName=@Name WHERE TemplateID=@ID", conn)
                cmd.Parameters.AddWithValue("@ID", templateId)
                cmd.Parameters.AddWithValue("@Name", newName)
                If cmd.ExecuteNonQuery() > 0 Then
                    response.Success = True
                Else
                    response.Success = False
                    response.ErrorMessage = "Template not found."
                End If
            End Using
        Catch ex As SqlException
            If ex.Number = 2627 Then
                response.Success = False : response.ErrorMessage = "A template with this name already exists."
            Else
                response.Success = False : response.ErrorMessage = "Database error renaming template: " & ex.Message
            End If
            System.Diagnostics.Debug.WriteLine($"SQL Error in RenameQueryTemplate: {ex.Message}{Environment.NewLine}{ex.StackTrace}")
        Catch ex As Exception
            response.Success = False
            response.ErrorMessage = "Error renaming template: " & ex.Message
            System.Diagnostics.Debug.WriteLine($"Error in RenameQueryTemplate: {ex.Message}{Environment.NewLine}{ex.StackTrace}")
        End Try
        Return response
    End Function

    <WebMethod()>
    Public Shared Function GetAllReports() As JsonResponse
        Dim response As New JsonResponse()
        Dim reports As New List(Of ReportInfoForList)()
        Try
            Dim connStr = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
            Using conn As New SqlConnection(connStr)
                conn.Open()
                Dim cmd As New SqlCommand("SELECT ReportID, ReportName FROM SavedReports ORDER BY ReportName", conn)
                Using reader = cmd.ExecuteReader()
                    While reader.Read()
                        reports.Add(New ReportInfoForList() With {
                            .ReportID = Convert.ToInt32(reader("ReportID")),
                            .ReportName = reader("ReportName").ToString()
                        })
                    End While
                End Using
            End Using
            response.Success = True
            response.Data = reports
        Catch ex As Exception
            response.Success = False
            response.ErrorMessage = "Error loading reports: " & ex.Message
            System.Diagnostics.Debug.WriteLine($"Error in GetAllReports: {ex.Message}{Environment.NewLine}{ex.StackTrace}")
        End Try
        Return response
    End Function

End Class
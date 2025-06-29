Imports System.Web.Services
Imports System.Data.SqlClient
Imports System.Configuration
Imports System.Collections.Generic
Imports System.Web.Script.Serialization
Imports System.Data
Imports System.Linq

Partial Class Creator
    Inherits System.Web.UI.Page

    Public Class JsonResponse
        Public Property Success As Boolean
        Public Property ErrorMessage As String
        Public Property Data As Object
        Public Property NeedsChartPrompt As Boolean
    End Class

    Public Class ReportSaveDTO
        Public Property ReportId As Integer
        Public Property ReportName As String
        Public Property SQLQuery As String
        Public Property Levels As List(Of DrillLevelDTO)
    End Class

    Public Class DrillLevelDTO
        Public Property Level As Integer
        Public Property SqlQuery As String
        Public Property QueryName As String
        Public Property ArgumentColumnName As String
    End Class

    Public Class QueryTemplateDTO
        Public Property TemplateName As String
        Public Property Description As String
        Public Property SQLQueryTemplate As String
    End Class

    Public Class VersionInfo
        Public Property VersionID As Integer
        Public Property SavedDate As String
        Public Property Username As String
        Public Property SQLQuery As String
    End Class

    Public Class ReportDetailsDTO
        Public Property ReportID As Integer
        Public Property ReportName As String
        Public Property SQLQuery As String
        Public Property DefaultChartType As String
    End Class

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Session("UserID") Is Nothing OrElse Session("Role") Is Nothing Then
            Session("UserID") = ConfigurationManager.AppSettings("TestUserID")
            Session("Role") = ConfigurationManager.AppSettings("TestUserRole")
        End If
    End Sub

    ' ▼▼▼ UPDATED: This will now work without crashing ▼▼▼
    <WebMethod(EnableSession:=True)>
    Public Shared Function RunLiveQuery(sqlQuery As String, level As Integer, isUpdate As Boolean) As JsonResponse
        Dim response As New JsonResponse()
        If String.IsNullOrWhiteSpace(sqlQuery) Then
            response.Success = False : response.ErrorMessage = "SQL query cannot be empty."
            Return response
        End If

        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
        Using conn As New SqlConnection(connectionString)
            Try
                conn.Open()
                Using cmd As New SqlCommand(sqlQuery, conn)
                    If Not sqlQuery.Trim().ToUpper().StartsWith("SELECT") Then
                        response.Success = False : response.ErrorMessage = "Only SELECT queries are allowed."
                        Return response
                    End If
                    Using adapter As New SqlDataAdapter(cmd)
                        Dim dt As New DataTable()
                        adapter.Fill(dt)
                        Dim dataRows = New List(Of Dictionary(Of String, Object))
                        Dim columns = dt.Columns.Cast(Of DataColumn)().Select(Function(c) c.ColumnName).ToList()
                        For Each row As DataRow In dt.Rows
                            Dim item = columns.ToDictionary(Function(c) c, Function(c) If(row(c) Is DBNull.Value, Nothing, row(c)))
                            dataRows.Add(item)
                        Next

                        ' Since LiveSessionManager is not available, we just return the local data
                        response.Success = True
                        response.Data = New With {
                            .LocalData = dataRows,
                            .Columns = columns,
                            .CurrentLevel = level,
                            .MaxLevel = level,
                            .FullSession = New With {
                                ._sessionLevels = New List(Of Object) From {
                                    New With {.Level = level, .SqlQuery = sqlQuery, .Data = dataRows, .Columns = columns}
                                }
                            }
                        }
                    End Using
                End Using
            Catch ex As Exception
                response.Success = False : response.ErrorMessage = "Database error: " & ex.Message
            End Try
        End Using
        Return response
    End Function

    <WebMethod(EnableSession:=True)>
    Public Shared Function ResetLiveSession() As JsonResponse
        Return New JsonResponse With {.Success = True}
    End Function

    <WebMethod(EnableSession:=True)>
    Public Shared Function SaveReport(reportData As ReportSaveDTO) As JsonResponse
        Dim response As New JsonResponse()
        Dim currentUserID As String = HttpContext.Current.Session("UserID")?.ToString()

        If String.IsNullOrWhiteSpace(currentUserID) Then
            response.Success = False : response.ErrorMessage = "User ID not found in session."
            Return response
        End If
        If String.IsNullOrWhiteSpace(reportData.ReportName) OrElse String.IsNullOrWhiteSpace(reportData.SQLQuery) Then
            response.Success = False : response.ErrorMessage = "Report Name and a Level 1 SQL Query are required."
            Return response
        End If

        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
        Using conn As New SqlConnection(connectionString)
            conn.Open()
            Using tran As SqlTransaction = conn.BeginTransaction()
                Try
                    Dim reportId As Integer = reportData.ReportId

                    If reportId = 0 Then
                        Dim insertSql As String = "INSERT INTO CustomReports (ReportName, SQLQuery, CreatedBy, CreatedDate, LastModified) " &
                                              "VALUES (@ReportName, @SQLQuery, @CreatedBy, GETDATE(), GETDATE()); SELECT SCOPE_IDENTITY();"
                        Using cmd As New SqlCommand(insertSql, conn, tran)
                            cmd.Parameters.AddWithValue("@ReportName", reportData.ReportName)
                            cmd.Parameters.AddWithValue("@SQLQuery", reportData.SQLQuery)
                            cmd.Parameters.AddWithValue("@CreatedBy", Integer.Parse(currentUserID))
                            reportId = Convert.ToInt32(cmd.ExecuteScalar())
                        End Using
                    Else
                        Dim updateSql As String = "UPDATE CustomReports SET ReportName = @ReportName, SQLQuery = @SQLQuery, LastModified = GETDATE() WHERE CustomReportID = @ReportID;"
                        Using cmd As New SqlCommand(updateSql, conn, tran)
                            cmd.Parameters.AddWithValue("@ReportName", reportData.ReportName)
                            cmd.Parameters.AddWithValue("@SQLQuery", reportData.SQLQuery)
                            cmd.Parameters.AddWithValue("@ReportID", reportId)
                            cmd.ExecuteNonQuery()
                        End Using

                        Dim delDrillSql As String = "DELETE FROM DrillDownQueries WHERE ReportID = @ReportID"
                        Using cmdDelDrill As New SqlCommand(delDrillSql, conn, tran)
                            cmdDelDrill.Parameters.AddWithValue("@ReportID", reportId)
                            cmdDelDrill.ExecuteNonQuery()
                        End Using
                    End If

                    Dim versionSql As String = "INSERT INTO ReportVersions (ReportID, SQLQuery, SavedBy, SavedDate) VALUES (@ReportID, @SQLQuery, @SavedBy, GETDATE());"
                    Using cmdVersion As New SqlCommand(versionSql, conn, tran)
                        cmdVersion.Parameters.AddWithValue("@ReportID", reportId)
                        cmdVersion.Parameters.AddWithValue("@SQLQuery", reportData.SQLQuery)
                        cmdVersion.Parameters.AddWithValue("@SavedBy", Integer.Parse(currentUserID))
                        cmdVersion.ExecuteNonQuery()
                    End Using

                    If reportData.Levels IsNot Nothing AndAlso reportData.Levels.Count > 0 Then
                        For Each lvl In reportData.Levels
                            Dim insertDrill As String = "INSERT INTO DrillDownQueries (ReportID, DrillLevel, QueryName, SQLQuerySnippet, ArgumentColumnName) VALUES (@ReportID, @Level, @QueryName, @SqlQuery, @ArgumentColumnName);"
                            Using cmd As New SqlCommand(insertDrill, conn, tran)
                                cmd.Parameters.AddWithValue("@ReportID", reportId)
                                cmd.Parameters.AddWithValue("@Level", lvl.Level)
                                cmd.Parameters.AddWithValue("@QueryName", If(String.IsNullOrEmpty(lvl.QueryName), "Level " & lvl.Level, lvl.QueryName))
                                cmd.Parameters.AddWithValue("@SqlQuery", lvl.SqlQuery)
                                cmd.Parameters.AddWithValue("@ArgumentColumnName", If(String.IsNullOrEmpty(lvl.ArgumentColumnName), DBNull.Value, lvl.ArgumentColumnName))
                                cmd.ExecuteNonQuery()
                            End Using
                        Next
                    End If

                    tran.Commit()
                    response.Success = True
                    response.Data = New With {.NewReportId = reportId}
                    response.NeedsChartPrompt = True
                Catch ex As SqlException
                    tran.Rollback()
                    If ex.Number = 2627 Then
                        response.Success = False : response.ErrorMessage = "A report with this name already exists."
                    Else
                        response.Success = False : response.ErrorMessage = "Database error saving report: " & ex.Message
                    End If
                Catch ex As Exception
                    tran.Rollback()
                    response.Success = False : response.ErrorMessage = "Error saving report: " & ex.Message
                End Try
            End Using
        End Using
        Return response
    End Function

    <WebMethod(EnableSession:=True)>
    Public Shared Function SaveReportChartType(reportId As Integer, chartType As String) As JsonResponse
        Dim response As New JsonResponse()
        Try
            Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
            Using conn As New SqlConnection(connectionString)
                conn.Open()
                Dim sql As String = "UPDATE CustomReports SET DefaultChartType = @ChartType WHERE CustomReportID = @ReportID;"
                Using cmd As New SqlCommand(sql, conn)
                    cmd.Parameters.AddWithValue("@ChartType", chartType)
                    cmd.Parameters.AddWithValue("@ReportID", reportId)
                    cmd.ExecuteNonQuery()
                End Using
            End Using
            response.Success = True
        Catch ex As Exception
            response.Success = False
            response.ErrorMessage = "Error saving chart type: " & ex.Message
        End Try
        Return response
    End Function

    <WebMethod()>
    Public Shared Function GetReportVersions(reportId As Integer) As JsonResponse
        Dim response As New JsonResponse()
        Dim versions As New List(Of VersionInfo)()
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
                            versions.Add(New VersionInfo() With {.VersionID = Convert.ToInt32(reader("VersionID")), .SavedDate = Convert.ToDateTime(reader("SavedDate")).ToString("g"), .Username = reader("Username").ToString(), .SQLQuery = reader("SQLQuery").ToString()})
                        End While
                    End Using
                End Using
                response.Success = True
                response.Data = versions
            Catch ex As Exception
                response.Success = False : response.ErrorMessage = "Error fetching version history: " & ex.Message
            End Try
        End Using
        Return response
    End Function

    <WebMethod(EnableSession:=True)>
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
                Dim sql As String = "INSERT INTO QueryTemplates (TemplateName, Description, SQLQueryTemplate, CreatedBy, CreatedDate) VALUES (@TemplateName, @Description, @SQLQueryTemplate, @CreatedBy, GETDATE());"
                Using cmd As New SqlCommand(sql, conn)
                    cmd.Parameters.AddWithValue("@TemplateName", templateData.TemplateName)
                    cmd.Parameters.AddWithValue("@Description", If(String.IsNullOrWhiteSpace(templateData.Description), DBNull.Value, templateData.Description))
                    cmd.Parameters.AddWithValue("@SQLQueryTemplate", templateData.SQLQueryTemplate)
                    cmd.Parameters.AddWithValue("@CreatedBy", Integer.Parse(currentUserID))
                    cmd.ExecuteNonQuery()
                    response.Success = True
                End Using
            Catch ex As SqlException
                If ex.Number = 2627 Then
                    response.Success = False : response.ErrorMessage = "A template with this name already exists."
                Else
                    response.Success = False : response.ErrorMessage = "Database error saving template: " & ex.Message
                End If
            Catch ex As Exception
                response.Success = False : response.ErrorMessage = "Error saving template: " & ex.Message
            End Try
        End Using
        Return response
    End Function

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
                            templates.Add(New With {.TemplateID = Convert.ToInt32(reader("TemplateID")), .TemplateName = reader("TemplateName").ToString(), .Description = reader("Description").ToString(), .SQLQueryTemplate = reader("SQLQueryTemplate").ToString()})
                        End While
                    End Using
                End Using
                response.Success = True
                response.Data = templates
            Catch ex As Exception
                response.Success = False : response.ErrorMessage = "Error fetching query templates: " & ex.Message
            End Try
        End Using
        Return response
    End Function

    <WebMethod()>
    Public Shared Function GetReportById(reportId As Integer) As JsonResponse
        Dim response As New JsonResponse()
        Try
            Dim connStr = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
            Using conn As New SqlConnection(connStr)
                conn.Open()
                Dim report As New Dictionary(Of String, Object)()
                Dim cmd As New SqlCommand("SELECT CustomReportID AS ReportID, ReportName, ISNULL(DefaultChartType,'Bar Chart') AS ChartType, ISNULL(SQLQuery, '') AS SQLQuery FROM CustomReports WHERE CustomReportID = @ReportID", conn)
                cmd.Parameters.AddWithValue("@ReportID", reportId)
                Using reader = cmd.ExecuteReader()
                    If reader.Read() Then
                        report("ReportID") = Convert.ToInt32(reader("ReportID"))
                        report("ReportName") = reader("ReportName").ToString()
                        report("ChartType") = reader("ChartType").ToString()
                        report("SQLQuery") = reader("SQLQuery").ToString()
                    Else
                        response.Success = False
                        response.ErrorMessage = "Report not found."
                        Return response
                    End If
                End Using
                Dim levels As New List(Of DrillLevelDTO)()
                Dim cmdLevels As New SqlCommand("SELECT DrillLevel AS Level, SQLQuerySnippet AS SqlQuery, QueryName, ISNULL(ArgumentColumnName,'') AS ArgumentColumnName FROM DrillDownQueries WHERE ReportID = @ReportID ORDER BY DrillLevel", conn)
                cmdLevels.Parameters.AddWithValue("@ReportID", reportId)
                Using reader = cmdLevels.ExecuteReader()
                    While reader.Read()
                        levels.Add(New DrillLevelDTO() With {
                            .Level = Convert.ToInt32(reader("Level")),
                            .SqlQuery = reader("SqlQuery").ToString(),
                            .QueryName = reader("QueryName").ToString(),
                            .ArgumentColumnName = reader("ArgumentColumnName").ToString()
                        })
                    End While
                End Using
                report("Levels") = levels
                response.Success = True
                response.Data = report
            End Using
        Catch ex As Exception
            response.Success = False
            response.ErrorMessage = "Error loading report: " & ex.Message
        End Try
        Return response
    End Function

    <WebMethod()>
    Public Shared Function DeleteReport(reportId As Integer) As JsonResponse
        Dim response As New JsonResponse()
        Try
            Dim connStr = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
            Using conn As New SqlConnection(connStr)
                conn.Open()
                Dim cmdDelLevels As New SqlCommand("DELETE FROM DrillDownQueries WHERE ReportID=@ReportID", conn)
                cmdDelLevels.Parameters.AddWithValue("@ReportID", reportId)
                cmdDelLevels.ExecuteNonQuery()
                Dim cmdDel As New SqlCommand("DELETE FROM CustomReports WHERE CustomReportID=@ReportID", conn)
                cmdDel.Parameters.AddWithValue("@ReportID", reportId)
                If cmdDel.ExecuteNonQuery() > 0 Then
                    response.Success = True
                Else
                    response.Success = False : response.ErrorMessage = "Not found."
                End If
            End Using
        Catch ex As Exception
            response.Success = False
            response.ErrorMessage = "Error deleting report: " & ex.Message
        End Try
        Return response
    End Function

    <WebMethod()>
    Public Shared Function RenameReport(reportId As Integer, newName As String) As JsonResponse
        Dim response As New JsonResponse()
        Try
            Dim connStr = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
            Using conn As New SqlConnection(connStr)
                conn.Open()
                Dim cmd As New SqlCommand("UPDATE CustomReports SET ReportName=@Name WHERE CustomReportID=@ID", conn)
                cmd.Parameters.AddWithValue("@ID", reportId)
                cmd.Parameters.AddWithValue("@Name", newName)
                If cmd.ExecuteNonQuery() > 0 Then
                    response.Success = True
                Else
                    response.Success = False
                    response.ErrorMessage = "Report not found."
                End If
            End Using
        Catch ex As Exception
            response.Success = False
            response.ErrorMessage = "Error renaming report: " & ex.Message
        End Try
        Return response
    End Function

    <WebMethod()>
    Public Shared Function DeleteQueryTemplate(templateId As Integer) As JsonResponse
        Dim response As New JsonResponse()
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
        End Try
        Return response
    End Function

    <WebMethod()>
    Public Shared Function RenameQueryTemplate(templateId As Integer, newName As String) As JsonResponse
        Dim response As New JsonResponse()
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
        Catch ex As Exception
            response.Success = False
            response.ErrorMessage = "Error renaming template: " & ex.Message
        End Try
        Return response
    End Function

    <WebMethod()>
    Public Shared Function GetAllReports() As JsonResponse
        Dim response As New JsonResponse()
        Dim reports As New List(Of Object)()
        Try
            Dim connStr = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
            Using conn As New SqlConnection(connStr)
                conn.Open()
                Dim cmd As New SqlCommand("SELECT CustomReportID AS ReportID, ReportName FROM CustomReports ORDER BY ReportName", conn)
                Using reader = cmd.ExecuteReader()
                    While reader.Read()
                        reports.Add(New With {
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
        End Try
        Return response
    End Function

End Class
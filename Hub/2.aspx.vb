' --- Add these Imports at the very top of your Viewer.aspx.vb file ---
Imports System.Web.Services
Imports System.Data.SqlClient
Imports System.Configuration
Imports System.Collections.Generic
Imports System.Web.Script.Serialization
Imports System.Data
Imports System.Text.RegularExpressions

Partial Class Viewer
    Inherits System.Web.UI.Page

    ' --- Utility Classes for JSON Responses and Data Transfer Objects (DTOs) ---
    Public Class JsonResponse
        Public Property Success As Boolean
        Public Property ErrorMessage As String
        Public Property Data As Object
        Public Property Reports As List(Of ReportInfo)
        Public Property Columns As List(Of String)
        Public Property Views As List(Of ViewInfo)
        Public Property ViewData As LoadedViewData
        Public Property FinalSQLQuery As String ' To send the final SQL query to frontend for visibility
        Public Property DrillDownQueryDefinitions As List(Of DrillDownQueryDefinition) ' NEW: For frontend to select drill queries
    End Class

    Public Class ReportInfo
        Public Property ReportID As Integer
        Public Property ReportName As String
        Public Property IsNew As Boolean
        Public Property PublishedDate As DateTime?
        Public Property DefaultViewID As Integer?
    End Class

    ' DTO for a single dimension filter
    Public Class DimensionFilter
        Public Property Field As String
        Public Property [Operator] As String
        Public Property Value As String
    End Class

    ' Updated DTO for GetReportData parameters
    Public Class ReportDataRequest
        Public Property ReportId As Integer
        Public Property TimeFilter As String
        Public Property DrillDownLevel As Integer
        Public Property DrillDownValue As String
        Public Property DimensionFilters As List(Of DimensionFilter)
        Public Property ActiveDrillDownQueryID As Integer? ' NEW: To specify which drill-down query to use
    End Class

    ' NEW: DTO for saving a view request from frontend
    Public Class SaveViewRequest
        Public Property ReportId As Integer
        Public Property ViewName As String
        Public Property DimensionFilters As List(Of DimensionFilter)
        Public Property DrillDownPath As List(Of DrillDownFilter)
        Public Property TimeFilter As String
        Public Property ChartType As String
    End Class

    ' NEW: DTO for loading available views list
    Public Class ViewInfo
        Public Property ViewID As Integer
        Public Property ViewName As String
    End Class

    ' NEW: DTO for loaded view data
    Public Class LoadedViewData
        Public Property DimensionFilters As List(Of DimensionFilter)
        Public Property DrillDownPath As List(Of DrillDownFilter)
        Public Property TimeFilter As String
        Public Property ChartType As String
    End Class

    ' Reusing this from existing code, ensures consistency for drill-down path DTO
    Public Class DrillDownFilter
        Public Property [Level] As Integer
        Public Property Value As String
        Public Property Name As String
        Public Property QueryID As Integer? ' NEW: Store the QueryID used for this drill level
    End Class

    ' NEW: DTO for drill-down query definitions from DB
    Public Class DrillDownQueryDefinition
        Public Property DrillDownQueryID As Integer
        Public Property ReportID As Integer ' NEW
        Public Property DrillLevel As Integer ' FIX: Ensure Public and correct type
        Public Property QueryName As String
        Public Property SQLQuerySnippet As String
        Public Property ArgumentColumnName As String
    End Class

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Session("UserID") Is Nothing OrElse Session("Role") Is Nothing Then
            Session("UserID") = ConfigurationManager.AppSettings("TestUserID")
            Session("Role") = ConfigurationManager.AppSettings("TestUserRole")
        End If
    End Sub

    <WebMethod(EnableSession:=True)>
    Public Shared Function GetAvailableReports() As JsonResponse
        Dim reports As New List(Of ReportInfo)()
        Dim response As New JsonResponse()
        Try
            Dim currentUserIDStr As String = HttpContext.Current.Session("UserID")?.ToString()
            Dim currentUserRole As String = HttpContext.Current.Session("Role")?.ToString()

            If String.IsNullOrEmpty(currentUserIDStr) OrElse String.IsNullOrEmpty(currentUserRole) Then
                response.Success = False
                response.ErrorMessage = "User not logged in or session data missing. Please log in again."
                Return response
            End If

            Dim currentUserID As Integer
            If Not Integer.TryParse(currentUserIDStr, currentUserID) Then
                response.Success = False
                response.ErrorMessage = "Invalid UserID format in session. Please check TestUserID in Web.config."
                Return response
            End If

            Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
            Using conn As New SqlConnection(connectionString)
                conn.Open()
                Dim sql As String = "SELECT ReportID, ReportName, IsNew, PublishedDate, DefaultViewID FROM SavedReports WHERE " &
                                    "CHARINDEX(',' + @UserID + ',', ',' + AllowedUsers + ',') > 0 " &
                                    "OR CHARINDEX(',' + @UserRole + ',', ',' + AllowedUsers + ',') > 0 " &
                                    "OR CHARINDEX(',All,', ',' + AllowedUsers + ',') > 0;"

                Using cmd As New SqlCommand(sql, conn)
                    cmd.Parameters.AddWithValue("@UserID", currentUserIDStr)
                    cmd.Parameters.AddWithValue("@UserRole", currentUserRole)
                    Using reader As SqlDataReader = cmd.ExecuteReader()
                        While reader.Read()
                            reports.Add(New ReportInfo() With {
                                .ReportID = Convert.ToInt32(reader("ReportID")),
                                .ReportName = reader("ReportName").ToString(),
                                .IsNew = If(reader("IsNew") Is DBNull.Value, False, Convert.ToBoolean(reader("IsNew"))),
                                .PublishedDate = If(reader("PublishedDate") Is DBNull.Value, CType(Nothing, DateTime?), CType(reader("PublishedDate"), DateTime?)),
                                .DefaultViewID = If(reader("DefaultViewID") Is DBNull.Value, CType(Nothing, Integer?), CType(reader("DefaultViewID"), Integer?))
                            })
                        End While
                    End Using
                End Using
            End Using
            response.Success = True
            response.Reports = reports
        Catch ex As Exception
            response.Success = False
            response.ErrorMessage = "Error fetching reports: " & ex.Message
            System.Diagnostics.Debug.WriteLine("Error in GetAvailableReports: " & ex.Message & Environment.NewLine & ex.StackTrace)
        End Try
        Return response
    End Function

    <WebMethod(EnableSession:=True)>
    Public Shared Function GetReportData(request As ReportDataRequest) As JsonResponse
        Dim response As New JsonResponse()
        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
        Dim sqlParams As New List(Of SqlParameter)()

        Using conn As New SqlConnection(connectionString)
            Try
                conn.Open()
                Dim savedSqlQuery As String = ""
                Dim getSqlQuery As String = "SELECT SQLQuery FROM SavedReports WHERE ReportID = @ReportID;"
                Using cmdGetSql As New SqlCommand(getSqlQuery, conn)
                    cmdGetSql.Parameters.AddWithValue("@ReportID", request.ReportId)
                    Dim result As Object = cmdGetSql.ExecuteScalar()
                    If result IsNot Nothing Then
                        savedSqlQuery = result.ToString()
                    Else
                        response.Success = False : response.ErrorMessage = "Report not found for the given ID."
                        Return response
                    End If
                End Using

                If String.IsNullOrWhiteSpace(savedSqlQuery) Then
                    response.Success = False : response.ErrorMessage = "SQL Query for this report is empty."
                    Return response
                End If

                Dim finalSqlQuery As String = BuildFinalQuery(savedSqlQuery, request, sqlParams)

                Using cmdExecute As New SqlCommand(finalSqlQuery, conn)
                    If sqlParams.Any() Then
                        cmdExecute.Parameters.AddRange(sqlParams.ToArray())
                    End If

                    Using adapter As New SqlDataAdapter(cmdExecute)
                        Dim dt As New DataTable()
                        adapter.Fill(dt)
                        Dim dataRows As New List(Of Dictionary(Of String, Object))
                        Dim columns As New List(Of String)()
                        For Each colObj As DataColumn In dt.Columns ' FIX: Changed 'col' to 'colObj' to avoid conflict
                            columns.Add(colObj.ColumnName)
                        Next
                        For Each row As DataRow In dt.Rows
                            Dim item As New Dictionary(Of String, Object)()
                            For Each colName As String In columns
                                item.Add(colName, If(row(colName) Is DBNull.Value, Nothing, row(colName)))
                            Next
                            dataRows.Add(item)
                        Next
                        response.Success = True
                        response.Data = dataRows
                        response.FinalSQLQuery = finalSqlQuery ' Return the final SQL query for viewer visibility
                        If (request.DimensionFilters Is Nothing OrElse Not request.DimensionFilters.Any()) AndAlso (request.DrillDownLevel = 0) Then
                            response.Columns = columns
                        End If
                    End Using
                End Using
            Catch ex As Exception
                response.Success = False
                response.ErrorMessage = "Error getting report data: " & ex.Message
                System.Diagnostics.Debug.WriteLine("Error in GetReportData: " & ex.Message & Environment.NewLine & ex.StackTrace)
            End Try
        End Using
        Return response
    End Function

    ' SaveView WebMethod
    <WebMethod(EnableSession:=True)>
    Public Shared Function SaveView(request As SaveViewRequest) As JsonResponse
        Dim response As New JsonResponse()
        Try
            Dim currentUserIDStr As String = HttpContext.Current.Session("UserID")?.ToString()
            If String.IsNullOrEmpty(currentUserIDStr) Then
                response.Success = False
                response.ErrorMessage = "User not logged in."
                Return response
            End If

            Dim currentUserID As Integer
            If Not Integer.TryParse(currentUserIDStr, currentUserID) Then
                response.Success = False
                response.ErrorMessage = "Invalid UserID format in session. Please ensure TestUserID in Web.config is a number, e.g., '1'."
                Return response
            End If

            Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
            Using conn As New SqlConnection(connectionString)
                conn.Open()

                ' --- PRE-CHECKS FOR FOREIGN KEY CONSTRAINTS (Crucial for robust saving) ---
                Using cmdCheckUser As New SqlCommand("SELECT COUNT(1) FROM Users WHERE UserID = @UserID", conn)
                    cmdCheckUser.Parameters.AddWithValue("@UserID", currentUserID)
                    If CType(cmdCheckUser.ExecuteScalar(), Integer) = 0 Then
                        response.Success = False
                        response.ErrorMessage = $"User ID '{currentUserID}' from session not found in the Users table. Please create this user or check TestUserID in Web.config."
                        Return response
                    End If
                End Using

                Using cmdCheckReport As New SqlCommand("SELECT COUNT(1) FROM SavedReports WHERE ReportID = @ReportID", conn)
                    cmdCheckReport.Parameters.AddWithValue("@ReportID", request.ReportId)
                    If CType(cmdCheckReport.ExecuteScalar(), Integer) = 0 Then
                        response.Success = False
                        response.ErrorMessage = $"Report with ID '{request.ReportId}' not found in SavedReports table. Please select a valid report that exists."
                        Return response
                    End If
                End Using
                ' --- END PRE-CHECKS ---

                Dim sql As String = "INSERT INTO SavedViews (UserID, ReportID, ViewName, FiltersJSON, DrillDownPathJSON, TimeFilter, ChartType) " &
                                    "VALUES (@UserID, @ReportID, @ViewName, @FiltersJSON, @DrillDownPathJSON, @TimeFilter, @ChartType);"

                Using cmd As New SqlCommand(sql, conn)
                    cmd.Parameters.AddWithValue("@UserID", currentUserID)
                    cmd.Parameters.AddWithValue("@ReportID", request.ReportId)
                    cmd.Parameters.AddWithValue("@ViewName", request.ViewName)
                    cmd.Parameters.AddWithValue("@TimeFilter", If(request.TimeFilter, DBNull.Value))
                    cmd.Parameters.AddWithValue("@ChartType", If(request.ChartType, DBNull.Value))

                    Dim serializer As New JavaScriptSerializer()

                    Dim filtersJson As Object = If(request.DimensionFilters IsNot Nothing AndAlso request.DimensionFilters.Any(), serializer.Serialize(request.DimensionFilters), DBNull.Value)
                    Dim drillDownPathJson As Object = If(request.DrillDownPath IsNot Nothing AndAlso request.DrillDownPath.Any(), serializer.Serialize(request.DrillDownPath), DBNull.Value)

                    cmd.Parameters.AddWithValue("@FiltersJSON", filtersJson)
                    cmd.Parameters.AddWithValue("@DrillDownPathJSON", drillDownPathJson)

                    cmd.ExecuteNonQuery()
                End Using
            End Using
            response.Success = True
        Catch ex As Exception
            response.Success = False
            response.ErrorMessage = "Error saving view: " & ex.Message
            System.Diagnostics.Debug.WriteLine("Error in SaveView: " & ex.Message & Environment.NewLine & ex.StackTrace)
        End Try
        Return response
    End Function

    ' LoadAvailableViews WebMethod
    <WebMethod(EnableSession:=True)>
    Public Shared Function LoadAvailableViews(reportId As Integer) As JsonResponse
        Dim response As New JsonResponse()
        Dim views As New List(Of ViewInfo)()
        Try
            Dim currentUserIDStr As String = HttpContext.Current.Session("UserID")?.ToString()
            If String.IsNullOrEmpty(currentUserIDStr) Then
                response.Success = False
                response.ErrorMessage = "User not logged in."
                Return response
            End If

            Dim currentUserID As Integer
            If Not Integer.TryParse(currentUserIDStr, currentUserID) Then
                response.Success = False
                response.ErrorMessage = "Invalid UserID format in session."
                Return response
            End If

            Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
            Using conn As New SqlConnection(connectionString)
                conn.Open()
                Dim sql As String = "SELECT ViewID, ViewName FROM SavedViews WHERE UserID = @UserID AND ReportID = @ReportID ORDER BY ViewName;"
                Using cmd As New SqlCommand(sql, conn)
                    cmd.Parameters.AddWithValue("@UserID", currentUserID)
                    cmd.Parameters.AddWithValue("@ReportID", reportId)
                    Using reader As SqlDataReader = cmd.ExecuteReader()
                        While reader.Read()
                            views.Add(New ViewInfo() With {
                                .ViewID = Convert.ToInt32(reader("ViewID")),
                                .ViewName = reader("ViewName").ToString()
                            })
                        End While
                    End Using
                End Using
            End Using
            response.Success = True
            response.Views = views
        Catch ex As Exception
            response.Success = False
            response.ErrorMessage = "Error loading available views: " & ex.Message
            System.Diagnostics.Debug.WriteLine("Error in LoadAvailableViews: " & ex.Message & Environment.NewLine & ex.StackTrace)
        End Try
        Return response
    End Function

    ' LoadView WebMethod
    <WebMethod(EnableSession:=True)>
    Public Shared Function LoadView(viewId As Integer) As JsonResponse
        Dim response As New JsonResponse()
        Try
            Dim currentUserIDStr As String = HttpContext.Current.Session("UserID")?.ToString()
            If String.IsNullOrEmpty(currentUserIDStr) Then
                response.Success = False
                response.ErrorMessage = "User not logged in."
                Return response
            End If

            Dim currentUserID As Integer
            If Not Integer.TryParse(currentUserIDStr, currentUserID) Then
                response.Success = False
                response.ErrorMessage = "Invalid UserID format in session."
                Return response
            End If

            Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
            Using conn As New SqlConnection(connectionString)
                conn.Open()
                Dim sql As String = "SELECT FiltersJSON, DrillDownPathJSON, TimeFilter, ChartType FROM SavedViews WHERE ViewID = @ViewID AND UserID = @UserID;"
                Using cmd As New SqlCommand(sql, conn)
                    cmd.Parameters.AddWithValue("@ViewID", viewId)
                    cmd.Parameters.AddWithValue("@UserID", currentUserID)
                    Using reader As SqlDataReader = cmd.ExecuteReader()
                        If reader.Read() Then
                            Dim loadedData As New LoadedViewData()
                            Dim serializer As New JavaScriptSerializer()

                            loadedData.TimeFilter = If(reader("TimeFilter") Is DBNull.Value, "NoFilter", reader("TimeFilter").ToString())
                            loadedData.ChartType = If(reader("ChartType") Is DBNull.Value, "GoogleBar", reader("ChartType").ToString())

                            If reader("FiltersJSON") IsNot DBNull.Value Then
                                loadedData.DimensionFilters = serializer.Deserialize(Of List(Of DimensionFilter))(reader("FiltersJSON").ToString())
                            Else
                                loadedData.DimensionFilters = New List(Of DimensionFilter)()
                            End If

                            If reader("DrillDownPathJSON") IsNot DBNull.Value Then
                                loadedData.DrillDownPath = serializer.Deserialize(Of List(Of DrillDownFilter))(reader("DrillDownPathJSON").ToString())
                            Else
                                loadedData.DrillDownPath = New List(Of DrillDownFilter)()
                            End If

                            response.Success = True
                            response.ViewData = loadedData
                        Else
                            response.Success = False
                            response.ErrorMessage = "View not found or access denied."
                        End If
                    End Using
                End Using
            End Using
        Catch ex As Exception
            response.Success = False
            response.ErrorMessage = "Error loading view: " & ex.Message
            System.Diagnostics.Debug.WriteLine("Error in LoadView: " & ex.Message & Environment.NewLine & ex.StackTrace)
        End Try
        Return response
    End Function

    ' BuildFinalQuery (logic for applying filters and drilldown)
    Private Shared Function BuildFinalQuery(originalQuery As String, request As ReportDataRequest, ByRef sqlParams As List(Of SqlParameter)) As String
        Dim currentQueryBase As String = originalQuery
        Dim orderByClause As String = ""
        Dim whereClauses As New List(Of String)()

        ' NEW: Dynamic Drill-Down Logic
        If request.DrillDownLevel > 0 AndAlso Not String.IsNullOrWhiteSpace(request.DrillDownValue) AndAlso request.ActiveDrillDownQueryID.HasValue Then
            ' FIX: Call GetDrillDownQueryDefinition as a Shared method (implicitly available in same class)
            Dim drillDownQueryDefinition As DrillDownQueryDefinition = GetDrillDownQueryDefinition(request.ActiveDrillDownQueryID.Value)
            If drillDownQueryDefinition IsNot Nothing Then
                Dim parameterizedQuery = drillDownQueryDefinition.SQLQuerySnippet.Replace("@DrillDownValue", "@DrillDownValueParam")
                sqlParams.Add(New SqlParameter("@DrillDownValueParam", request.DrillDownValue))
                Return parameterizedQuery
            End If
        End If

        Dim orderByRegex As New Regex("\sORDER BY\s+.+(\sASC|\sDESC)?\s*$", RegexOptions.IgnoreCase)
        Dim match As Match = orderByRegex.Match(currentQueryBase)

        If match.Success Then
            orderByClause = match.Value
            currentQueryBase = orderByRegex.Replace(currentQueryBase, "").Trim()
        End If

        Dim wrappedQuery As String = $"SELECT * FROM ({currentQueryBase}) AS BaseQuery"

        If request.DimensionFilters IsNot Nothing AndAlso request.DimensionFilters.Any() Then
            For i As Integer = 0 To request.DimensionFilters.Count - 1
                Dim filter As DimensionFilter = request.DimensionFilters(i)
                If String.IsNullOrWhiteSpace(filter.Field) OrElse Not Regex.IsMatch(filter.Field, "^[a-zA-Z0-9_]+$") Then
                    Continue For
                End If

                Dim paramName As String = $"@FilterValue{sqlParams.Count}"
                Dim clause As String = ""

                Select Case filter.Operator.ToLower()
                    Case "equals"
                        clause = $"[{filter.Field}] = {paramName}"
                        sqlParams.Add(New SqlParameter(paramName, filter.Value))
                    Case "notequals"
                        clause = $"[{filter.Field}] <> {paramName}"
                        sqlParams.Add(New SqlParameter(paramName, filter.Value))
                    Case "contains"
                        clause = $"[{filter.Field}] LIKE '%' + {paramName} + '%'"
                        sqlParams.Add(New SqlParameter(paramName, filter.Value))
                    Case "doesnotcontain"
                        clause = $"[{filter.Field}] NOT LIKE '%' + {paramName} + '%'"
                        sqlParams.Add(New SqlParameter(paramName, filter.Value))
                    Case "startswith"
                        clause = $"[{filter.Field}] LIKE {paramName} + '%'"
                        sqlParams.Add(New SqlParameter(paramName, filter.Value))
                    Case "endswith"
                        clause = $"[{filter.Field}] LIKE '%' + {paramName}"
                        sqlParams.Add(New SqlParameter(paramName, filter.Value))
                    Case "greaterthan"
                        clause = $"[{filter.Field}] > {paramName}"
                        sqlParams.Add(New SqlParameter(paramName, filter.Value))
                    Case "lessthan"
                        clause = $"[{filter.Field}] < {paramName}"
                        sqlParams.Add(New SqlParameter(paramName, filter.Value))
                    Case Else
                        Continue For
                End Select

                If Not String.IsNullOrEmpty(clause) Then
                    whereClauses.Add(clause)
                End If
            Next
        End If

        Dim timeFilterClause As String = GenerateTimeFilterClause(request.TimeFilter)
        If Not String.IsNullOrWhiteSpace(timeFilterClause) Then
            whereClauses.Add(timeFilterClause)
        End If

        Dim finalQueryWithFilters As String = wrappedQuery
        If whereClauses.Any() Then
            finalQueryWithFilters = $"{wrappedQuery} WHERE {String.Join(" AND ", whereClauses)}"
        End If

        If Not String.IsNullOrWhiteSpace(orderByClause) Then
            finalQueryWithFilters = $"{finalQueryWithFilters} {orderByClause}"
        End If

        Return finalQueryWithFilters
    End Function

    Private Shared Function GenerateTimeFilterClause(timeFilter As String) As String
        If String.IsNullOrWhiteSpace(timeFilter) OrElse timeFilter.ToLower() = "nofilter" Then
            Return ""
        End If

        Dim filterClause As String = ""
        Dim dateColumnPlaceholder As String = "OrderDate" ' Default for dummy tables; can be made dynamic later

        Select Case timeFilter.ToLower()
            Case "today"
                filterClause = $"[{dateColumnPlaceholder}] >= CAST(GETDATE() AS DATE) AND [{dateColumnPlaceholder}] < DATEADD(DAY, 1, CAST(GETDATE() AS DATE))"
            Case "yesterday"
                filterClause = $"[{dateColumnPlaceholder}] >= DATEADD(DAY, -1, CAST(GETDATE() AS DATE)) AND [{dateColumnPlaceholder}] < CAST(GETDATE() AS DATE)"
            Case "last7days"
                filterClause = $"[{dateColumnPlaceholder}] >= DATEADD(DAY, -7, CAST(GETDATE() AS DATE)) AND [{dateColumnPlaceholder}] <= CAST(GETDATE() AS DATE)"
            Case "thismonth"
                filterClause = $"[{dateColumnPlaceholder}] >= DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0) AND [{dateColumnPlaceholder}] < DATEADD(month, DATEDIFF(month, 0, GETDATE()) + 1, 0)"
            Case "lastmonth"
                filterClause = $"[{dateColumnPlaceholder}] >= DATEADD(month, DATEDIFF(month, 0, GETDATE()) - 1, 0) AND [{dateColumnPlaceholder}] < DATEADD(month, DATEDIFF(month, 0, GETDATE()), 0)"
            Case "thisyear"
                filterClause = $"[{dateColumnPlaceholder}] >= DATEADD(year, DATEDIFF(year, 0, GETDATE()), 0) AND [{dateColumnPlaceholder}] < DATEADD(year, DATEDIFF(year, 0, GETDATE()) + 1, 0)"
        End Select

        Return filterClause
    End Function

    ' NEW: GetDrillDownQueryDefinitions WebMethod (for Creator to define, Viewer to list options)
    ' This method needs to be public shared to be accessed as a WebMethod
    <WebMethod(EnableSession:=True)>
    Public Shared Function GetDrillDownQueryDefinitions(reportId As Integer, drillLevel As Integer) As JsonResponse
        Dim response As New JsonResponse()
        Dim definitions As New List(Of DrillDownQueryDefinition)()
        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
        Using conn As New SqlConnection(connectionString)
            Try
                conn.Open()
                Dim sql As String = "SELECT DrillDownQueryID, ReportID, DrillLevel, QueryName, SQLQuerySnippet, ArgumentColumnName " &
                                    "FROM DrillDownQueries WHERE ReportID = @ReportID AND DrillLevel = @DrillLevel " &
                                    "ORDER BY QueryName;"
                Using cmd As New SqlCommand(sql, conn)
                    cmd.Parameters.AddWithValue("@ReportID", reportId)
                    cmd.Parameters.AddWithValue("@DrillLevel", drillLevel)
                    Using reader As SqlDataReader = cmd.ExecuteReader()
                        While reader.Read()
                            definitions.Add(New DrillDownQueryDefinition() With {
                                .DrillDownQueryID = Convert.ToInt32(reader("DrillDownQueryID")),
                                .ReportID = Convert.ToInt32(reader("ReportID")), ' NEW
                                .DrillLevel = Convert.ToInt32(reader("DrillLevel")), ' FIX: Ensure proper assignment
                                .QueryName = reader("QueryName").ToString(),
                                .SQLQuerySnippet = reader("SQLQuerySnippet").ToString(),
                                .ArgumentColumnName = If(reader("ArgumentColumnName") Is DBNull.Value, Nothing, reader("ArgumentColumnName").ToString())
                            })
                        End While
                    End Using
                End Using
                response.Success = True
                response.Data = definitions
            Catch ex As Exception
                response.Success = False
                response.ErrorMessage = "Error fetching drill-down query definitions: " & ex.Message
                System.Diagnostics.Debug.WriteLine("Error in GetDrillDownQueryDefinitions: " & ex.Message & Environment.NewLine & ex.StackTrace)
            End Try
        End Using
        Return response
    End Function

    ' Private helper function to get a single drill-down definition
    ' FIX: Changed from GetDrillDownQuery to GetDrillDownQueryDefinition for clarity and correct DTO
    ' Made it Shared for BuildFinalQuery to access it.
    Private Shared Function GetDrillDownQueryDefinition(drillDownQueryID As Integer) As DrillDownQueryDefinition
        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
        Using conn As New SqlConnection(connectionString)
            Try
                conn.Open()
                Dim sql As String = "SELECT DrillDownQueryID, ReportID, DrillLevel, QueryName, SQLQuerySnippet, ArgumentColumnName FROM DrillDownQueries WHERE DrillDownQueryID = @DrillDownQueryID;"
                Using cmd As New SqlCommand(sql, conn)
                    cmd.Parameters.AddWithValue("@DrillDownQueryID", drillDownQueryID)
                    Using reader As SqlDataReader = cmd.ExecuteReader()
                        If reader.Read() Then
                            Return New DrillDownQueryDefinition() With {
                                .DrillDownQueryID = Convert.ToInt32(reader("DrillDownQueryID")),
                                .ReportID = Convert.ToInt32(reader("ReportID")),
                                .DrillLevel = Convert.ToInt32(reader("DrillLevel")),
                                .QueryName = reader("QueryName").ToString(),
                                .SQLQuerySnippet = reader("SQLQuerySnippet").ToString(),
                                .ArgumentColumnName = If(reader("ArgumentColumnName") Is DBNull.Value, Nothing, reader("ArgumentColumnName").ToString())
                            }
                        End If
                    End Using
                End Using
            Catch ex As Exception
                System.Diagnostics.Debug.WriteLine("Error in GetDrillDownQueryDefinition (helper): " & ex.Message & Environment.NewLine & ex.StackTrace)
            End Try
        End Using
        Return Nothing ' Return Nothing if not found or error
    End Function


    ' NEW: SaveDrillDownQueryDefinition WebMethod (for Creator to save)
    <WebMethod(EnableSession:=True)>
    Public Shared Function SaveDrillDownQueryDefinition(definition As DrillDownQueryDefinition, reportId As Integer) As JsonResponse
        Dim response As New JsonResponse()
        Try
            If String.IsNullOrWhiteSpace(definition.QueryName) OrElse String.IsNullOrWhiteSpace(definition.SQLQuerySnippet) OrElse definition.DrillLevel <= 0 Then
                response.Success = False : response.ErrorMessage = "Query Name, SQL Snippet, and Drill Level are required."
                Return response
            End If

            Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
            Using conn As New SqlConnection(connectionString)
                conn.Open()
                Dim sql As String
                If definition.DrillDownQueryID > 0 Then ' Update existing
                    sql = "UPDATE DrillDownQueries SET QueryName = @QueryName, SQLQuerySnippet = @SQLQuerySnippet, ArgumentColumnName = @ArgumentColumnName, DrillLevel = @DrillLevel " &
                          "WHERE DrillDownQueryID = @DrillDownQueryID AND ReportID = @ReportID;"
                Else ' Insert new
                    sql = "INSERT INTO DrillDownQueries (ReportID, DrillLevel, QueryName, SQLQuerySnippet, ArgumentColumnName) " &
                          "VALUES (@ReportID, @DrillLevel, @QueryName, @SQLQuerySnippet, @ArgumentColumnName);"
                End If

                Using cmd As New SqlCommand(sql, conn)
                    cmd.Parameters.AddWithValue("@ReportID", reportId)
                    cmd.Parameters.AddWithValue("@DrillLevel", definition.DrillLevel)
                    cmd.Parameters.AddWithValue("@QueryName", definition.QueryName)
                    cmd.Parameters.AddWithValue("@SQLQuerySnippet", definition.SQLQuerySnippet)
                    cmd.Parameters.AddWithValue("@ArgumentColumnName", If(String.IsNullOrWhiteSpace(definition.ArgumentColumnName), DBNull.Value, definition.ArgumentColumnName))
                    If definition.DrillDownQueryID > 0 Then
                        cmd.Parameters.AddWithValue("@DrillDownQueryID", definition.DrillDownQueryID)
                    End If
                    cmd.ExecuteNonQuery()
                    response.Success = True
                End Using
            End Using
        Catch ex As SqlException
            If ex.Number = 2627 Then ' Unique constraint violation (ReportID, DrillLevel, QueryName)
                response.Success = False
                response.ErrorMessage = "A drill-down query with this name already exists for this report and level."
            Else
                response.Success = False
                response.ErrorMessage = "Database error saving drill-down query: " & ex.Message
            End If
            System.Diagnostics.Debug.WriteLine("SQL Error in SaveDrillDownQueryDefinition: " & ex.Message & Environment.NewLine & ex.StackTrace)
        Catch ex As Exception
            response.Success = False
            response.ErrorMessage = "Error saving drill-down query: " & ex.Message
            System.Diagnostics.Debug.WriteLine("Error in SaveDrillDownQueryDefinition: " & ex.Message & Environment.NewLine & ex.StackTrace)
        End Try
        Return response
    End Function

    ' NEW: DeleteDrillDownQueryDefinition WebMethod (for Creator to delete)
    <WebMethod(EnableSession:=True)>
    Public Shared Function DeleteDrillDownQueryDefinition(drillDownQueryID As Integer) As JsonResponse
        Dim response As New JsonResponse()
        Try
            Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
            Using conn As New SqlConnection(connectionString)
                conn.Open()
                Dim sql As String = "DELETE FROM DrillDownQueries WHERE DrillDownQueryID = @DrillDownQueryID;"
                Using cmd As New SqlCommand(sql, conn)
                    cmd.Parameters.AddWithValue("@DrillDownQueryID", drillDownQueryID)
                    cmd.ExecuteNonQuery()
                    response.Success = True
                End Using
            End Using
        Catch ex As Exception
            response.Success = False
            response.ErrorMessage = "Error deleting drill-down query: " & ex.Message
            System.Diagnostics.Debug.WriteLine("Error in DeleteDrillDownQueryDefinition: " & ex.Message & Environment.NewLine & ex.StackTrace)
        End Try
        Return response
    End Function

End Class
' --- Add these Imports at the very top of your Viewer.aspx.vb file ---
Imports System.Web.Services
Imports System.Data.SqlClient
Imports System.Configuration
Imports System.Collections.Generic
Imports System.Web.Script.Serialization
Imports System.Data
Imports System.Text.RegularExpressions
Imports System.Linq
Imports System.Web
Imports System.Diagnostics ' Ensure this is present

' Removed SignalR Imports

Partial Class Viewer
    Inherits System.Web.UI.Page

    ' --- Utility Classes for JSON Responses and Data Transfer Objects (DTOs) ---
    Public Class JsonResponse
        Public Property Success As Boolean
        Public Property ErrorMessage As String
        Public Property Data As Object ' Can be List(Of Dictionary) or List(Of DTO)
        Public Property Reports As List(Of ReportInfo) ' For GetAvailableReports
        Public Property Columns As List(Of String) ' Return columns for the current level data
        Public Property FinalSQLQuery As String ' To send the final SQL query to frontend for visibility (optional in simple mode)
        ' Removed DrillDownQueryDefinitions from here - returned in Data property of GetDrillDownQueryDefinitions response
    End Class

    ' DTO for Report List (Viewer side) - Includes DefaultChartType
    Public Class ReportInfo
        Public Property ReportID As Integer
        Public Property ReportName As String
        Public Property IsNew As Boolean
        Public Property PublishedDate As DateTime?
        Public Property DefaultChartType As String ' Include default chart type
    End Class

    ' DimensionFilter DTO (Keep structure but not used in client JS for simplicity)
    Public Class DimensionFilter
        Public Property Field As String
        Public Property [Operator] As String
        Public Property Value As String
    End Class

    ' DTO for GetReportData parameters
    ' Keep full structure for future expansion, even if client sends minimal data now
    Public Class ReportDataRequest
        Public Property ReportId As Integer
        Public Property TimeFilter As String ' Client will send "NoFilter"
        Public Property DrillDownLevel As Integer ' The level we are requesting data for (0 is base)
        ' Public Property DrillDownValue As Object ' Removed - can be derived from FullDrillDownPath
        ' Public Property ActiveDrillDownQueryID As Integer? ' Removed - server determines query based on DrillDownLevel and ReportId
        Public Property FullDrillDownPath As List(Of DrillDownFilter) ' The complete path of drill-down steps
        ' DimensionFilters are NOT used in this simplified version
        ' Public Property DimensionFilters As List(Of DimensionFilter)
    End Class

    ' SaveViewRequest, ViewInfo, LoadedViewData DTOs are removed for simplicity


    ' DTO for a single step in the drill-down path
    Public Class DrillDownFilter
        Public Property [Level] As Integer ' The level *this step represents* (1, 2, 3, 4) in the path
        Public Property Value As Object    ' The value selected at the *previous* level
        Public Property Name As String     ' Display name for the value
        Public Property QueryID As Integer? ' The ID of the DrillDownQueryDefinition used to *get to this level*
    End Class

    ' DTO for drill-down query definitions from DB
    Public Class DrillDownQueryDefinition
        Public Property DrillDownQueryID As Integer
        Public Property ReportID As Integer
        Public Property DrillLevel As Integer ' The DB defined level (2, 3, 4, etc.)
        Public Property QueryName As String
        Public Property SQLQuerySnippet As String
        Public Property ArgumentColumnName As String
    End Class

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        ' Session check and test user assignment
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

    ' GetAvailableReports WebMethod - Fetches reports user has access to
    ' Simplified: Added DefaultChartType to ReportInfo DTO
    <WebMethod(EnableSession:=True)>
    Public Shared Function GetAvailableReports() As JsonResponse
        Dim reports As New List(Of ReportInfo)()
        Dim response As New JsonResponse()
        Try
            Dim currentUserIDStr As String = HttpContext.Current.Session("UserID")?.ToString()
            Dim currentUserRole As String = HttpContext.Current.Session("Role")?.ToString()

            If String.IsNullOrEmpty(currentUserIDStr) OrElse String.IsNullOrEmpty(currentUserRole) Then
                response.Success = False
                response.ErrorMessage = "User not logged in or session data missing."
                Return response
            End If

            Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
            Using conn As New SqlConnection(connectionString)
                conn.Open()
                ' Select reports user has access to, include DefaultChartType
                Dim sql As String = "SELECT ReportID, ReportName, IsNew, PublishedDate, DefaultChartType FROM SavedReports WHERE " &
                                    "CHARINDEX(',' + @UserID + ',', ',' + AllowedUsers + ',') > 0 " &
                                    "OR CHARINDEX(',' + @UserRole + ',', ',' + AllowedUsers + ',') > 0 " &
                                    "OR CHARINDEX(',All,', ',' + AllowedUsers + ',') > 0 " &
                                    "ORDER BY ReportName;"

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
                                .DefaultChartType = If(reader("DefaultChartType") Is DBNull.Value, "GoogleBar", reader("DefaultChartType").ToString()) ' Read chart type
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
            System.Diagnostics.Debug.WriteLine($"Error in GetAvailableReports: {ex.Message}{Environment.NewLine}{ex.StackTrace}")
        End Try
        Return response
    End Function

    ' GetReportData WebMethod - Fetches data based on current drill level and path
    ' Determines which query (base or snippet) to run based on DrillDownLevel
    <WebMethod(EnableSession:=True)>
    Public Shared Function GetReportData(request As ReportDataRequest) As JsonResponse
        Dim response As New JsonResponse()
        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
        Dim sqlParams As New List(Of SqlParameter)()
        Dim queryToExecute As String = ""
        Dim finalSqlQuery As String = ""

        Using conn As New SqlConnection(connectionString)
            Try
                conn.Open()

                ' Determine the SQL query to run based on the DrillDownLevel requested
                If request.DrillDownLevel = 0 Then
                    ' Level 0 (Base Report) - Get query from SavedReports
                    Dim getSqlQuery As String = "SELECT SQLQuery FROM SavedReports WHERE ReportID = @ReportID;"
                    Using cmdGetSql As New SqlCommand(getSqlQuery, conn)
                        cmdGetSql.Parameters.AddWithValue("@ReportID", request.ReportId)
                        Dim result As Object = cmdGetSql.ExecuteScalar()
                        If result IsNot Nothing Then
                            queryToExecute = result.ToString()
                        Else
                            response.Success = False
                            response.ErrorMessage = "Report not found or base query is empty."
                            Return response
                        End If
                    End Using ' End Using for cmdGetSql
                    System.Diagnostics.Debug.WriteLine($"DEBUG: Using Base Query for Level {request.DrillDownLevel}.")
                Else ' This Else matches the first If request.DrillDownLevel = 0 Then
                    ' Drill-Down Level (1, 2, 3 representing steps Year, Month, Day)
                    ' The DB DrillLevel is 1 higher than the path level (2 for Month, 3 for Day, 4 for Hour)
                    Dim dbDrillLevel = request.DrillDownLevel + 1

                    ' Find the specific drill-down query definition for this DB level and report
                    Dim drillDef = GetDrillDownQueryDefinitionByLevel(request.ReportId, dbDrillLevel)

                    If drillDef IsNot Nothing Then
                        queryToExecute = drillDef.SQLQuerySnippet
                        System.Diagnostics.Debug.WriteLine($"DEBUG: Using DrillDownQuery definition for ReportID {request.ReportId}, DB DrillLevel {dbDrillLevel}.")
                    Else
                        response.Success = False
                        response.ErrorMessage = $"Drill-down query definition not found for ReportID {request.ReportId}, DB DrillLevel {dbDrillLevel}."
                        Return response
                    End If ' End If for drillDef IsNot Nothing
                End If ' End If for request.DrillDownLevel = 0 Then

                If String.IsNullOrWhiteSpace(queryToExecute) Then
                    response.Success = False
                    response.ErrorMessage = $"SQL Query for level {request.DrillDownLevel} is empty after selection."
                    Return response
                End If ' End If for String.IsNullOrWhiteSpace(queryToExecute)

                ' Build the final query by wrapping the queryToExecute and adding parameters
                ' Time filters and Dimension filters are NOT applied in this simplified version's BuildFinalQuery
                finalSqlQuery = BuildFinalQuery(queryToExecute, request.FullDrillDownPath, sqlParams)
                System.Diagnostics.Debug.WriteLine($"DEBUG: Final SQL Query: {finalSqlQuery}")


                Using cmdExecute As New SqlCommand(finalSqlQuery, conn)
                    If sqlParams.Any() Then
                        cmdExecute.Parameters.AddRange(sqlParams.ToArray())
                        ' Log parameters for debugging
                        If System.Diagnostics.Debug.Listeners.Count > 0 Then ' Only write if a listener is attached
                            Dim paramLog = String.Join(", ", sqlParams.Select(Function(p) $"{p.ParameterName}='{If(p.Value Is DBNull.Value, "NULL", p.Value.ToString())}'"))
                            System.Diagnostics.Debug.WriteLine($"DEBUG: SQL Parameters: {paramLog}")
                        End If
                    Else
                        System.Diagnostics.Debug.WriteLine("DEBUG: No SQL Parameters.")
                    End If

                    Using adapter As New SqlDataAdapter(cmdExecute)
                        Dim dt As New DataTable()
                        adapter.Fill(dt)

                        Dim dataRows As New List(Of Dictionary(Of String, Object))()
                        Dim columns As New List(Of String)()

                        ' Get column names
                        For Each col As DataColumn In dt.Columns
                            columns.Add(col.ColumnName)
                        Next

                        ' Get data rows as dictionaries
                        For Each row As DataRow In dt.Rows
                            Dim item As New Dictionary(Of String, Object)()
                            For Each colName As String In columns
                                ' Handle DBNull values
                                item.Add(colName, If(row(colName) Is DBNull.Value, Nothing, row(colName)))
                            Next
                            dataRows.Add(item)
                        Next

                        response.Success = True
                        response.Data = dataRows
                        response.FinalSQLQuery = finalSqlQuery ' Return the final SQL query (optional)
                        response.Columns = columns ' Return columns for the frontend

                    End Using ' End Using for adapter
                End Using ' End Using for cmdExecute
            Catch ex As Exception
                response.Success = False
                response.ErrorMessage = "Error getting report data: " & ex.Message
                response.FinalSQLQuery = finalSqlQuery ' Include the potentially problematic query
                System.Diagnostics.Debug.WriteLine($"Error in GetReportData: {ex.Message}{Environment.NewLine}{ex.StackTrace}")
            End Try
        End Using ' End Using for conn
        Return response
    End Function

    ' BuildFinalQuery - Constructs the final SQL query for the drill level
    ' SIMPLIFIED: Only handles wrapping the base query/snippet and adding drill path parameters
    Private Shared Function BuildFinalQuery(baseQueryOrSnippet As String, fullDrillDownPath As List(Of DrillDownFilter), ByRef sqlParams As List(Of SqlParameter)) As String
        Dim currentQuery = baseQueryOrSnippet
        Dim orderByClause As String = ""

        ' 1. Extract and remove ORDER BY clause (standard practice before wrapping)
        ' Using a more robust regex to handle potential comments or multiple lines before ORDER BY
        Dim orderByRegex As New Regex("\s*ORDER BY\s+.*$", RegexOptions.IgnoreCase Or RegexOptions.RightToLeft)
        Dim match As Match = orderByRegex.Match(currentQuery)

        If match.Success Then
            orderByClause = match.Value.Trim()
            ' Remove the matched ORDER BY clause from the end of the query
            currentQuery = currentQuery.Substring(0, match.Index).Trim()
        End If ' End If for match.Success

        ' 2. Add Parameters for Drill Path Values
        ' Iterate through the full drill path and add parameters for each step.
        ' Parameters will be named @Level1Value, @Level2Value, etc., matching the step's Level property (1-based).
        ' These parameter names must match the placeholders used in the SQLQuerySnippets
        If fullDrillDownPath IsNot Nothing Then
            For i As Integer = 0 To fullDrillDownPath.Count - 1
                Dim drillStep = fullDrillDownPath(i)
                ' Parameter name based on the *step number* (1-based) in the path, not the DB DrillLevel
                Dim paramName = $"@Level{drillStep.Level}Value"
                ' Add parameter. Convert DBNull.Value or Nothing to DBNull.Value for the parameter.
                sqlParams.Add(New SqlParameter(paramName, If(drillStep.Value Is Nothing OrElse drillStep.Value Is DBNull.Value, DBNull.Value, drillStep.Value)))
                System.Diagnostics.Debug.WriteLine($"DEBUG: Added param {paramName} with value '{If(drillStep.Value Is Nothing, "NULL", drillStep.Value.ToString())}'")
            Next
        End If ' End If for fullDrillDownPath IsNot Nothing

        ' 3. Wrap the base query/snippet in a subquery
        ' This allows the WHERE clauses within the snippet (using @LevelNValue) to function correctly
        ' and provides a consistent structure.
        Dim wrappedQuery As String = $"SELECT * FROM ({currentQuery}) AS BaseLevelData"

        ' 4. Time Filters and Dimension Filters are SKIPPED in this simplified version.
        ' Dim whereClauses As New List(Of String)()
        ' Dim timeFilterClause As String = GenerateTimeFilterClause(request.TimeFilter)
        ' ... logic to add filter clauses ...
        ' If whereClauses.Any() Then finalQueryWithFilters = $"{wrappedQuery} WHERE {String.Join(" AND ", whereClauses)}" ...


        Dim finalQuery = wrappedQuery

        ' 5. Add the ORDER BY clause back if it was extracted
        If Not String.IsNullOrWhiteSpace(orderByClause) Then
            finalQuery = $"{finalQuery} {orderByClause}"
        End If ' End If for Not String.IsNullOrWhiteSpace(orderByClause)

        Return finalQuery
    End Function

    ' GenerateTimeFilterClause - Helper to create SQL WHERE clause for time filters
    ' Keep the logic but it's not called by the simplified BuildFinalQuery
    Private Shared Function GenerateTimeFilterClause(timeFilter As String) As String
        ' This function is not used in the simplified BuildFinalQuery, but kept for structure/future use.
        Return "" ' Always return empty in simplified mode
    End Function

    ' GetDrillDownQueryDefinitions WebMethod - Fetches ALL definitions for a report
    ' Returns definitions for all levels (2, 3, 4 etc.) for the given report
    <WebMethod(EnableSession:=True)>
    Public Shared Function GetDrillDownQueryDefinitions(reportId As Integer) As JsonResponse ' Removed drillLevel param
        Dim response As New JsonResponse()
        Dim definitions As New List(Of DrillDownQueryDefinition)()
        If reportId <= 0 Then
            response.Success = False : response.ErrorMessage = "Invalid Report ID."
            Return response
        End If ' End If for reportId <= 0

        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
        Using conn As New SqlConnection(connectionString)
            Try
                conn.Open()
                ' Select ALL definitions for the given report ID
                Dim sql As String = "SELECT DrillDownQueryID, ReportID, DrillLevel, QueryName, SQLQuerySnippet, ArgumentColumnName " &
                                    "FROM DrillDownQueries WHERE ReportID = @ReportID " &
                                    "ORDER BY DrillLevel, QueryName;" ' Order by level and name

                Using cmd As New SqlCommand(sql, conn)
                    cmd.Parameters.AddWithValue("@ReportID", reportId)
                    Using reader As SqlDataReader = cmd.ExecuteReader()
                        While reader.Read()
                            definitions.Add(New DrillDownQueryDefinition() With {
                                .DrillDownQueryID = Convert.ToInt32(reader("DrillDownQueryID")),
                                .ReportID = Convert.ToInt32(reader("ReportID")),
                                .DrillLevel = Convert.ToInt32(reader("DrillLevel")),
                                .QueryName = reader("QueryName").ToString(),
                                .SQLQuerySnippet = reader("SQLQuerySnippet").ToString(),
                                .ArgumentColumnName = If(reader("ArgumentColumnName") Is DBNull.Value, Nothing, reader("ArgumentColumnName").ToString())
                            })
                        End While
                    End Using ' End Using for reader
                End Using ' End Using for cmd
                response.Success = True
                response.Data = definitions ' Return the list of definitions in the Data property
            Catch ex As Exception
                response.Success = False
                response.ErrorMessage = "Error fetching drill-down query definitions: " & ex.Message
                System.Diagnostics.Debug.WriteLine($"Error in GetDrillDownQueryDefinitions: {ex.Message}{Environment.NewLine}{ex.StackTrace}")
            End Try
        End Using ' End Using for conn
        Return response
    End Function


    ' Helper function to get a single drill-down definition by ReportID and DB DrillLevel
    ' Used internally by GetReportData to find the correct query snippet
    Private Shared Function GetDrillDownQueryDefinitionByLevel(reportId As Integer, dbDrillLevel As Integer) As DrillDownQueryDefinition
        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
        Using conn As New SqlConnection(connectionString)
            Try
                conn.Open()
                Dim sql As String = "SELECT DrillDownQueryID, ReportID, DrillLevel, QueryName, SQLQuerySnippet, ArgumentColumnName FROM DrillDownQueries WHERE ReportID = @ReportID AND DrillLevel = @DrillLevel;"
                Using cmd As New SqlCommand(sql, conn)
                    cmd.Parameters.AddWithValue("@ReportID", reportId)
                    cmd.Parameters.AddWithValue("@DrillLevel", dbDrillLevel) ' Corrected variable name
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
                        End If ' End If for reader.Read()
                    End Using ' End Using for reader
                End Using ' End Using for cmd
            Catch ex As Exception
                System.Diagnostics.Debug.WriteLine($"Error in GetDrillDownQueryDefinitionByLevel (helper): {ex.Message}{Environment.NewLine}{ex.StackTrace}")
            End Try
        End Using ' End Using for conn
        Return Nothing ' Return Nothing if not found or error
    End Function

End Class
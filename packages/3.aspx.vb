' --- Add these Imports at the very top of your Viewer.aspx.vb file ---
Imports System.Web.Services
Imports System.Data.SqlClient
Imports System.Configuration
Imports System.Collections.Generic
Imports System.Web.Script.Serialization
Imports System.Data
Imports System.Text.RegularExpressions ' Import Regex namespace

Partial Class Viewer
    Inherits System.Web.UI.Page

    ' --- Utility Classes for JSON Responses and Data Transfer Objects (DTOs) ---
    Public Class JsonResponse
        Public Property Success As Boolean
        Public Property ErrorMessage As String
        Public Property Data As Object
        Public Property Reports As List(Of ReportInfo)
        Public Property Columns As List(Of String) ' To send available columns for filtering
    End Class

    Public Class ReportInfo
        Public Property ReportID As Integer
        Public Property ReportName As String
    End Class

    ' DTO for a single dimension filter
    Public Class DimensionFilter
        Public Property Field As String
        Public Property [Operator] As String ' Using [] to allow 'Operator' as a property name
        Public Property Value As String
    End Class

    ' Updated DTO for GetReportData parameters
    Public Class ReportDataRequest
        Public Property ReportId As Integer
        Public Property TimeFilter As String
        Public Property DrillDownLevel As Integer
        Public Property DrillDownValue As String
        Public Property DimensionFilters As List(Of DimensionFilter)
    End Class

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Session("UserID") Is Nothing OrElse Session("Role") Is Nothing Then
            Session("UserID") = ConfigurationManager.AppSettings("TestUserID")
            Session("Role") = ConfigurationManager.AppSettings("TestUserRole")
        End If
    End Sub

    <WebMethod()>
    Public Shared Function GetAvailableReports() As JsonResponse
        Dim reports As New List(Of ReportInfo)()
        Dim response As New JsonResponse()
        Try
            Dim currentUserID As String = HttpContext.Current.Session("UserID")?.ToString()
            Dim currentUserRole As String = HttpContext.Current.Session("Role")?.ToString()

            If String.IsNullOrEmpty(currentUserID) OrElse String.IsNullOrEmpty(currentUserRole) Then
                response.Success = False
                response.ErrorMessage = "User not logged in or session data missing. Please log in again."
                Return response
            End If

            Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
            Using conn As New SqlConnection(connectionString)
                conn.Open()
                Dim sql As String = "SELECT ReportID, ReportName FROM SavedReports WHERE " &
                                    "CHARINDEX(',' + @UserID + ',', ',' + AllowedUsers + ',') > 0 " &
                                    "OR CHARINDEX(',' + @UserRole + ',', ',' + AllowedUsers + ',') > 0 " &
                                    "OR CHARINDEX(',All,', ',' + AllowedUsers + ',') > 0;"

                Using cmd As New SqlCommand(sql, conn)
                    cmd.Parameters.AddWithValue("@UserID", currentUserID)
                    cmd.Parameters.AddWithValue("@UserRole", currentUserRole)
                    Using reader As SqlDataReader = cmd.ExecuteReader()
                        While reader.Read()
                            reports.Add(New ReportInfo() With {
                                .ReportID = Convert.ToInt32(reader("ReportID")),
                                .ReportName = reader("ReportName").ToString()
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

    <WebMethod()>
    Public Shared Function GetReportData(request As ReportDataRequest) As JsonResponse
        Dim response As New JsonResponse()
        Dim connectionString As String = ConfigurationManager.ConnectionStrings("DefaultConnection").ConnectionString
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

                Dim finalSqlQuery As String = ApplyFiltersAndDrillDown(savedSqlQuery, request)

                Using cmdExecute As New SqlCommand(finalSqlQuery, conn)
                    ' Parameterize drill-down and filter values
                    If request.DrillDownLevel > 0 AndAlso Not String.IsNullOrWhiteSpace(request.DrillDownValue) Then
                        cmdExecute.Parameters.AddWithValue("@DrillDownValue", request.DrillDownValue)
                    End If
                    If request.DimensionFilters IsNot Nothing Then
                        For i As Integer = 0 To request.DimensionFilters.Count - 1
                            Dim filter As DimensionFilter = request.DimensionFilters(i)
                            Dim paramValue As String = filter.Value
                            If filter.Operator.ToLower() = "contains" OrElse filter.Operator.ToLower() = "doesnotcontain" Then
                                paramValue = $"%{filter.Value}%"
                            ElseIf filter.Operator.ToLower() = "startswith" Then
                                paramValue = $"{filter.Value}%"
                            ElseIf filter.Operator.ToLower() = "endswith" Then
                                paramValue = $"%{filter.Value}"
                            End If
                            cmdExecute.Parameters.AddWithValue($"@FilterValue{i}", paramValue)
                        Next
                    End If

                    Using adapter As New SqlDataAdapter(cmdExecute)
                        Dim dt As New DataTable()
                        adapter.Fill(dt)
                        Dim dataRows As New List(Of Dictionary(Of String, Object))
                        Dim columns As New List(Of String)()
                        For Each col As DataColumn In dt.Columns
                            columns.Add(col.ColumnName)
                        Next
                        For Each row As DataRow In dt.Rows
                            Dim item As New Dictionary(Of String, Object)()
                            For Each colName As String In columns
                                item.Add(colName, row(colName))
                            Next
                            dataRows.Add(item)
                        Next
                        response.Success = True
                        response.Data = dataRows
                        If (request.DimensionFilters Is Nothing OrElse request.DimensionFilters.Count = 0) AndAlso request.DrillDownLevel = 0 Then
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

    Private Shared Function ApplyFiltersAndDrillDown(sqlQuery As String, request As ReportDataRequest) As String
        If request.DrillDownLevel > 0 AndAlso Not String.IsNullOrWhiteSpace(request.DrillDownValue) Then
            Dim drillDownQuery As String = GetDrillDownQuery(request)
            If Not String.IsNullOrWhiteSpace(drillDownQuery) Then
                Return drillDownQuery
            End If
        End If

        Dim queryWithDimensionFilters As String = ApplyDimensionFilters(sqlQuery, request.DimensionFilters)
        Dim finalQuery As String = ApplyTimeFilter(queryWithDimensionFilters, request.TimeFilter)
        Return finalQuery
    End Function

    Private Shared Function ApplyDimensionFilters(sqlQuery As String, filters As List(Of DimensionFilter)) As String
        If filters Is Nothing OrElse filters.Count = 0 Then
            Return sqlQuery
        End If

        Dim whereClauses As New List(Of String)()
        For i As Integer = 0 To filters.Count - 1
            Dim filter As DimensionFilter = filters(i)
            If String.IsNullOrWhiteSpace(filter.Field) OrElse Not filter.Field.Replace("_", "").All(AddressOf Char.IsLetterOrDigit) Then
                Continue For
            End If

            Dim op As String = "="
            Select Case filter.Operator.ToLower()
                Case "equals" : op = "="
                Case "notequals" : op = "<>"
                Case "contains" : op = "LIKE"
                Case "doesnotcontain" : op = "NOT LIKE"
                Case "startswith" : op = "LIKE"
                Case "endswith" : op = "LIKE"
                Case "greaterthan" : op = ">"
                Case "lessthan" : op = "<"
            End Select
            whereClauses.Add($"[{filter.Field}] {op} @FilterValue{i}")
        Next

        If whereClauses.Count = 0 Then
            Return sqlQuery
        End If

        Dim combinedWhereClause As String = String.Join(" AND ", whereClauses)
        Dim lowerQuery As String = sqlQuery.Trim().ToLower()
        If lowerQuery.Contains(" where ") Then
            Dim regex As New Regex("\s(group|order)\sby\s", RegexOptions.IgnoreCase)
            Dim match As Match = regex.Match(sqlQuery)
            If match.Success Then
                Return sqlQuery.Insert(match.Index, $" AND {combinedWhereClause} ")
            Else
                Return sqlQuery & $" AND {combinedWhereClause}"
            End If
        Else
            Dim regex As New Regex("\s(group|order)\sby\s", RegexOptions.IgnoreCase)
            Dim match As Match = regex.Match(sqlQuery)
            If match.Success Then
                Return sqlQuery.Insert(match.Index, $" WHERE {combinedWhereClause} ")
            Else
                Return sqlQuery & $" WHERE {combinedWhereClause}"
            End If
        End If
    End Function

    Private Shared Function ApplyTimeFilter(sqlQuery As String, timeFilter As String) As String
        If String.IsNullOrWhiteSpace(timeFilter) OrElse timeFilter.ToLower() = "nofilter" Then
            Return sqlQuery
        End If

        Dim filterClause As String = ""
        Dim dateColumnPlaceholder As String = "OrderDate"

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

        If String.IsNullOrWhiteSpace(filterClause) Then
            Return sqlQuery
        End If

        Dim lowerQuery As String = sqlQuery.ToLower()
        Dim whereKeyword As String = " WHERE "
        If lowerQuery.Contains(whereKeyword.Trim()) Then
            whereKeyword = " AND "
        End If

        Dim regex As New Regex("\s(group|order)\sby\s", RegexOptions.IgnoreCase)
        Dim match As Match = regex.Match(sqlQuery)
        If match.Success Then
            Return sqlQuery.Insert(match.Index, $"{whereKeyword}{filterClause} ")
        Else
            Return sqlQuery & $"{whereKeyword}{filterClause}"
        End If
    End Function

    Private Shared Function GetDrillDownQuery(request As ReportDataRequest) As String
        Dim drillDownSpecificQuery As String = ""
        ' Important: Sanitize drillDownValue before using in a query
        Dim safeDrillDownValue As String = request.DrillDownValue.Replace("'", "''")

        Select Case request.ReportId
            Case 1 ' Monthly Sales Summary
                Select Case request.DrillDownLevel
                    Case 1 ' From Month to Daily Sales
                        drillDownSpecificQuery = "SELECT CAST(OrderDate AS DATE) AS OrderDay, SUM(Amount) AS DailySales " &
                                                 "FROM DummySalesTable WHERE FORMAT(OrderDate, 'yyyy-MM') = @DrillDownValue GROUP BY CAST(OrderDate AS DATE) ORDER BY OrderDay;"
                    Case 2 ' From Day to Sales by Product Category
                        drillDownSpecificQuery = "SELECT ProductCategory, SUM(Amount) AS TotalSales " &
                                                 "FROM DummySalesTable WHERE CAST(OrderDate AS DATE) = @DrillDownValue GROUP BY ProductCategory ORDER BY TotalSales DESC;"
                    Case 3 ' From Product Category to Sales by Region
                        drillDownSpecificQuery = "SELECT Region, SUM(Amount) AS TotalSales " &
                                                 "FROM DummySalesTable WHERE ProductCategory = @DrillDownValue GROUP BY Region ORDER BY Region;"
                End Select
            Case 2 ' Product Inventory Levels
                Select Case request.DrillDownLevel
                    Case 1 ' From Product Name to details
                        drillDownSpecificQuery = "SELECT ProductID, ProductName, StockQuantity, Manufacturer, Description " &
                                                 "FROM DummyProductsTable WHERE ProductName = @DrillDownValue;"
                End Select
        End Select
        Return drillDownSpecificQuery
    End Function

End Class
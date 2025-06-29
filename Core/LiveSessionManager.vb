Imports System.Collections.Generic
Imports System.Linq
Imports Newtonsoft.Json

Public Class LiveSessionManager

#Region "Singleton Setup"
    Private Shared ReadOnly _instance As New LiveSessionManager()
    Private Sub New()
    End Sub
    Public Shared ReadOnly Property Current As LiveSessionManager
        Get
            Return _instance
        End Get
    End Property
#End Region

    Public Class LiveSessionLevel
        Public Property Level As Integer
        Public Property SqlQuery As String
        Public Property Data As List(Of Dictionary(Of String, Object))
        Public Property Columns As List(Of String)
    End Class

    <JsonProperty("_sessionLevels")>
    Public ReadOnly Property _sessionLevels As New List(Of LiveSessionLevel)()

    <JsonProperty("CurrentVisibleLevel")>
    Public Property CurrentVisibleLevel As Integer = 1

    ' यह मेथड एक नया लेवल जोड़ता है और उसके बाद के सभी लेवल्स को हटा देता है
    Public Sub UpdateSession(levelData As LiveSessionLevel)
        _sessionLevels.RemoveAll(Function(l) l.Level >= levelData.Level)
        _sessionLevels.Add(levelData)
        CurrentVisibleLevel = levelData.Level
    End Sub

    ' NEW: नया मेथड जो किसी मौजूदा लेवल को उसकी जगह पर अपडेट करता है
    Public Function UpdateSpecificLevel(levelData As LiveSessionLevel) As Boolean
        Dim existingLevel = _sessionLevels.FirstOrDefault(Function(l) l.Level = levelData.Level)
        If existingLevel IsNot Nothing Then
            existingLevel.SqlQuery = levelData.SqlQuery
            existingLevel.Data = levelData.Data
            existingLevel.Columns = levelData.Columns
            CurrentVisibleLevel = levelData.Level
            Return True ' Update सफल हुआ
        End If
        Return False ' लेवल नहीं मिला
    End Function

    Public Function GetLevel(level As Integer) As LiveSessionLevel
        Return _sessionLevels.FirstOrDefault(Function(l) l.Level = level)
    End Function

    Public Sub ResetSession()
        _sessionLevels.Clear()
        CurrentVisibleLevel = 1
    End Sub

    <JsonProperty("GetMaxLevel")>
    Public ReadOnly Property GetMaxLevel As Integer
        Get
            If _sessionLevels.Any() Then
                Return _sessionLevels.Max(Function(l) l.Level)
            Else
                Return 0
            End If
        End Get
    End Property
End Class
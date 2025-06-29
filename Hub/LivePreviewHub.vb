Imports Microsoft.AspNet.SignalR
Imports System.Threading.Tasks
Imports Vision

Namespace Hubs
    Public Class LivePreviewHub
        Inherits Hub

        ' This method allows a client (like the viewer) to request a navigation
        ' The server then broadcasts this change to ALL clients to keep them in sync.
        Public Sub NavigateToLevel(level As Integer)
            Dim sessionManager = LiveSessionManager.Current
            Dim levelData = sessionManager.GetLevel(level)

            If levelData IsNot Nothing Then
                sessionManager.CurrentVisibleLevel = level
                ' Broadcast the updated session state to all clients
                Clients.All.updateViewer(sessionManager)
            End If
        End Sub

    End Class
End Namespace
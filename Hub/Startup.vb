Imports Microsoft.Owin
Imports Owin

' यह लाइन बहुत महत्वपूर्ण है। यह OWIN को बताती है कि स्टार्टअप पर इस क्लास को चलाना है।
<Assembly: OwinStartup(GetType(Vision.Startup))>

Namespace Vision
    Public Class Startup
        Public Sub Configuration(ByVal app As IAppBuilder)
            ' यह लाइन आपके प्रोजेक्ट में सभी SignalR हब को ढूंढती है और उन्हें पंजीकृत करती है।
            app.MapSignalR()
        End Sub
    End Class
End Namespace
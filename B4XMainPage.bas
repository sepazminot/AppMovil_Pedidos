B4A=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=9.85
@EndOfDesignText@
#Region Shared Files
#CustomBuildAction: folders ready, %WINDIR%\System32\Robocopy.exe,"..\..\Shared Files" "..\Files"
'Ctrl + click to sync files: ide://run?file=%WINDIR%\System32\Robocopy.exe&args=..\..\Shared+Files&args=..\Files&FilesSync=True
#End Region

'Ctrl + click to export as zip: ide://run?File=%B4X%\Zipper.jar&Args=%PROJECT_NAME%.zip

Sub Class_Globals
	Private Root As B4XView
	Private xui As XUI
	Public sql1 As SQL
	Public const DB_NAME As String = "pedidos.db"
	Private registro As registro
	Private txtusuario As EditText
	Private txtclave As EditText
End Sub

Public Sub Initialize
'	B4XPages.GetManager.LogEvents = True
End Sub

'This event will be called once, before the page becomes visible.
Private Sub B4XPage_Created (Root1 As B4XView)
	Root = Root1
	registro.Initialize
	B4XPages.AddPage("registro", registro)
	#If B4A
	sql1.Initialize(File.DirInternal, DB_NAME, True)
    #End If
	CrearTablaPedidos
	Root.LoadLayout("MainPage")
End Sub

Private Sub btningresar_Click
	If txtusuario.Text.Trim = "" Or txtclave.Text.Trim = "" Then
		xui.MsgboxAsync("Por favor, ingrese usuario y contraseña", "Datos incompletos")
		Return
	End If
    
	' 2. Preparar la petición a la API
	Dim j As HttpJob
	j.Initialize("", Me)
    
	Dim datos As Map = CreateMap("username": txtusuario.Text, "password": txtclave.Text)
	Dim jg As JSONGenerator
	jg.Initialize(datos)
    
	Dim url As String = "https://api-pedidos-o0t9.onrender.com/auth/login"
    
	j.PostString(url, jg.ToString)
	j.GetRequest.SetContentType("application/json")
    
	Wait For (j) JobDone(j As HttpJob)
    
	If j.Success Then
		Dim jp As JSONParser
		jp.Initialize(j.GetString)
		Dim respuesta As Map = jp.NextObject
        
		Dim token As String = respuesta.Get("token")
        
		File.WriteString(File.DirInternal, "token_auth.txt", token)
        
		Log("Login exitoso. Token guardado.")
        
		B4XPages.ShowPage("registro")
	Else
		xui.MsgboxAsync("Error de autenticación: " & j.ErrorMessage, "Acceso Denegado")
	End If
	j.Release
End Sub

Private Sub CrearTablaPedidos
	Dim query As String
	query = "CREATE TABLE IF NOT EXISTS pedidos (" & _
            "id INTEGER PRIMARY KEY AUTOINCREMENT, " & _
            "cliente TEXT, " & _
            "telefono TEXT, " & _
            "direccion TEXT, " & _
            "detalle TEXT, " & _
            "tipo_pago TEXT, " & _
            "foto_path TEXT, " & _
            "latitud REAL, " & _
            "longitud REAL, " & _
            "fecha DATETIME, " & _
            "estado TEXT, " & _ 
            "error_msg TEXT)" 
	sql1.ExecNonQuery(query)
End Sub

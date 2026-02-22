B4A=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=13.4
@EndOfDesignText@
Sub Class_Globals
	Private Root As B4XView 'ignore
	Private xui As XUI 'ignore
	Private txtnombre As EditText
	Private txttelefono As EditText
	Private txtdireccion As EditText
	Private txtdetalle As EditText
	Private rbtrans As RadioButton
	Private rbefectivo As RadioButton
	Private gps1 As GPS
	Private lblubicacion As Label ' El que pusiste en el Designer
	Private latActual, lonActual As Double =0
	Private rp As RuntimePermissions
	Private NombreFotoActual As String = ""
	Private ivimg As ImageView
	Private pedidos As pedidos
	Private zx1 As ZxingBarcodeScanner
	Private btnescanear As Button
	Private btntomarimg As Button
	Private btnguardar As Button
	Private btnpedidos As Button
	Private btncancelarscan As Button
End Sub

'You can add more parameters here.
Public Sub Initialize As Object
	Return Me
End Sub

'This event will be called once, before the page becomes visible.
Private Sub B4XPage_Created (Root1 As B4XView)
	Root = Root1
	'load the layout to Root
	Root.LoadLayout("registro")
	pedidos.Initialize
	B4XPages.AddPage("pedidos",pedidos)
	
	If zx1.IsInitialized Then
		zx1.Visible = False
		zx1.LaserColor = xui.Color_Red
		zx1.MaskColor = xui.Color_ARGB(150, 0, 0, 0)
		zx1.BorderColor = xui.Color_White
		zx1.BorderStrokeWidth = 5dip
		zx1.BorderLineLength = 40dip
	End If
	btncancelarscan.Visible= False
	SolicitarPermisoGPS
End Sub

Sub btnguardar_Click
	If txtnombre.Text = "" Or txttelefono.Text = "" Then
		xui.MsgboxAsync("Nombre y Teléfono son obligatorios", "Error")
		Return
	End If

	If latActual = 0 Or lonActual = 0 Then
		Dim res As Object = xui.Msgbox2Async("No se ha capturado la ubicación GPS. ¿Guardar de todas formas?", "Aviso", "Sí", "", "No", Null)
		Wait For (res) Msgbox_Result (Result As Int)
		If Result <> xui.DialogResponse_Positive Then Return
	End If

	' Capturar el tipo de pago de los RadioButtons
	Dim tipoPago As String = "efectivo"
	If rbtrans.Checked Then tipoPago = "transferencia"

	' Insertar en SQLite local
	Dim sql As String = "INSERT INTO pedidos (cliente, telefono, direccion, detalle, tipo_pago, foto_path, latitud, longitud, fecha, estado) " & _
                        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    
	' 4. Manejo de la Fecha
	DateTime.DateFormat = "yyyy-MM-dd HH:mm:ss"
	Dim fechaActual As String = DateTime.Date(DateTime.Now)
	
	Try
		Dim nuevoNombre As String = "foto_" & DateTime.Now & ".jpg"
		File.Copy(rp.GetSafeDirDefaultExternal(""), "foto_pedido.jpg", rp.GetSafeDirDefaultExternal(""), nuevoNombre)
		NombreFotoActual = nuevoNombre
		B4XPages.MainPage.sql1.ExecNonQuery2(sql, Array As Object( _
            txtnombre.Text, _
            txttelefono.Text, _
            txtdireccion.Text, _
            txtdetalle.Text, _
            tipoPago, _
            NombreFotoActual, _
            latActual, _
            lonActual, _
            fechaActual, _
            "Pendiente"))
            
		xui.MsgboxAsync("Pedido guardado localmente (Offline)", "Éxito")
        
		LimpiarFormulario
	Catch
		Log(LastException)
		xui.MsgboxAsync("Error al guardar en la base de datos", "Error")
	End Try
End Sub

Sub SolicitarPermisoGPS
	rp.CheckAndRequest(rp.PERMISSION_ACCESS_FINE_LOCATION)
	Wait For B4XPage_PermissionResult (Permission As String, Result As Boolean)
	If Result Then
		IniciarCapturaGPS
	Else
		xui.MsgboxAsync("No se puede obtener ubicación sin permisos", "Error")
	End If
End Sub

Sub IniciarCapturaGPS
	If gps1.IsInitialized = False Then gps1.Initialize("gps1")
	gps1.Start(0, 0) ' Captura lo más rápido posible
End Sub

Sub gps1_LocationChanged (Location1 As Location)
	latActual = Location1.Latitude
	lonActual = Location1.Longitude
	lblubicacion.Text = "Lat: " & latActual & " | Lon: " & lonActual
	gps1.Stop
End Sub

Sub btntomarimg_Click
	NombreFotoActual = "foto_pedido.jpg"
    
	Try
		Dim i As Intent
		Dim rp As RuntimePermissions
		
		rp.CheckAndRequest(rp.PERMISSION_CAMERA)
		Wait For B4XPage_PermissionResult (Permission As String, Result As Boolean)
    
		If Result = False Then
			xui.MsgboxAsync("No se puede tomar la foto sin permiso de la cámara", "Permiso denegado")
			Return
		End If
		
		Dim Directorio As String = rp.GetSafeDirDefaultExternal("")
        
		If File.Exists(Directorio, NombreFotoActual) Then File.Delete(Directorio, NombreFotoActual)

		i.Initialize("android.media.action.IMAGE_CAPTURE", "")
        
		Dim f As JavaObject
		Dim context As JavaObject
		context.InitializeContext
        
		Dim fileObj As JavaObject
		fileObj.InitializeNewInstance("java.io.File", Array(Directorio, NombreFotoActual))
        
		Dim uri As Object = f.InitializeStatic("androidx.core.content.FileProvider").RunMethod("getUriForFile", _
            Array(context, Application.PackageName & ".fileprovider", fileObj))
        
		i.PutExtra("output", uri)
		i.Flags = 3 ' READ + WRITE
        
		StartActivity(i)
	Catch
		Log(LastException)
	End Try
End Sub

Sub B4XPage_Appear
	' Solo intentamos cargar si NombreFotoActual NO está vacío
	If NombreFotoActual <> "" Then
		Dim rp As RuntimePermissions
		Dim Directorio As String = rp.GetSafeDirDefaultExternal("")
        
		' Verifica que el archivo exista REALMENTE
		If File.Exists(Directorio, NombreFotoActual) Then
			Log("Cargando archivo: " & Directorio & "/" & NombreFotoActual)
			Try
				If ivimg.Width > 0 Then
					ivimg.Bitmap = xui.LoadBitmapResize(Directorio, NombreFotoActual, ivimg.Width, ivimg.Height, True)
				Else
					ivimg.Bitmap = xui.LoadBitmap(Directorio, NombreFotoActual)
				End If
			Catch
				Log("Error al cargar bitmap: " & LastException)
			End Try
		End If
	End If
End Sub

' Este evento captura el resultado de la cámara en B4XPages
Public Sub B4XPage_ActivityResult (RequestCode As Int, ResultCode As Int, Data As Intent)
	Log("Resultado de cámara recibido. Código: " & ResultCode)
    
	If RequestCode = 100 And ResultCode = -1 Then ' -1 es RESULT_OK
		Try
			' Extraer la miniatura
			If Data.IsInitialized Then
				Dim jo As JavaObject = Data
				Dim extras As JavaObject = jo.RunMethod("getExtras", Null)
            
				If extras.IsInitialized Then
					Dim bmp As B4XBitmap = extras.RunMethod("get", Array("data"))
					ivimg.Bitmap = bmp
                
					' Guardar físicamente para el SQLite
					Dim out As OutputStream = File.OpenOutput(File.DirInternal, NombreFotoActual, False)
					bmp.WriteToStream(out, 100, "JPEG")
					out.Close
					Log("Foto guardada: " & NombreFotoActual)
				End If
			End If
		Catch
			Log("Error procesando foto: " & LastException)
		End Try
	Else
		Log("Cámara cancelada o fallida")
		NombreFotoActual = ""
	End If
End Sub

Private Sub LimpiarFormulario
	txtnombre.Text = ""
	txttelefono.Text = ""
	txtdireccion.Text = ""
	txtdetalle.Text = ""
	ivimg.Bitmap=Null
	NombreFotoActual = ""
	latActual = 0
	lonActual = 0
	lblubicacion.Text = "Ubicación: Sin capturar"
End Sub

Sub btnpedidos_Click
	B4XPages.ShowPage("pedidos")
End Sub

Sub btnescanear_Click
	rp.CheckAndRequest(rp.PERMISSION_CAMERA)
	Wait For B4XPage_PermissionResult (Permission As String, Result As Boolean)
    
	If Result = False Then
		xui.MsgboxAsync("No se puede tomar la foto sin permiso de la cámara", "Permiso denegado")
		Return
	End If
	AlternarVisibilidadControles(False)
	btncancelarscan.Visible= True
	zx1.Visible = True
	zx1.BringToFront ' Lo ponemos por encima de los otros controles
	zx1.startScanner
End Sub

Sub zx1_scan_result (scantext As String, scanformat As String)
	zx1.stopScanner
	zx1.Visible = False
	AlternarVisibilidadControles(True)
	Log("QR Detectado: " & scantext)
    
	RellenarCamposDesdeQR(scantext)
	btncancelarscan.Visible = False
End Sub

Sub RellenarCamposDesdeQR(Contenido As String)
	Try
		Dim partes() As String = Regex.Split("\|", Contenido)
        
		For Each parte As String In partes
			Dim llaveValor() As String = Regex.Split("=", parte)
            
			If llaveValor.Length = 2 Then
				Dim llave As String = llaveValor(0).Trim.ToUpperCase
				Dim valor As String = llaveValor(1).Trim
                
				Select llave
					Case "CLIENTE"
						txtnombre.Text = valor
					Case "TEL"
						txttelefono.Text = valor
					Case "DIR"
						txtdireccion.Text = valor
				End Select
			End If
		Next
        
		ToastMessageShow("Datos cargados correctamente", False)
        
	Catch
		Log(LastException)
		MsgboxAsync("El formato del QR no es compatible", "Aviso")
	End Try
End Sub

Sub Activity_Pause (UserClosed As Boolean)
	If zx1.IsInitialized Then
		zx1.stopScanner
	End If
End Sub

Private Sub AlternarVisibilidadControles(Visible As Boolean)
	txtnombre.Visible = Visible
	txttelefono.Visible = Visible
	txtdireccion.Visible = Visible
	txtdetalle.Visible = Visible
	btnescanear.Visible = Visible
	btntomarimg.Visible = Visible
	btnguardar.Visible = Visible
	btnpedidos.Visible=Visible
	lblubicacion.Visible = Visible
	ivimg.Visible = Visible
	rbefectivo.Visible = Visible
	rbtrans.Visible = Visible
End Sub

Sub btncancelarscan_Click
	zx1.stopScanner
	zx1.Visible = False
	btncancelarscan.Visible = False
	AlternarVisibilidadControles(True)
End Sub
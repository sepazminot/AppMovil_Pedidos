B4A=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=13.4
@EndOfDesignText@
Sub Class_Globals
	Private Root As B4XView 'ignore
	Private xui As XUI 'ignore
	Private clvPedidos As CustomListView ' Requiere librería XUI Views
	Private sql1 As SQL
	Private pgDetalle As pgDetalle
End Sub

'You can add more parameters here.
Public Sub Initialize As Object
	Return Me
End Sub

'This event will be called once, before the page becomes visible.
Private Sub B4XPage_Created (Root1 As B4XView)
	Root = Root1
	'load the layout to Root
	Root.LoadLayout("pedidos")
	CargarPedidosLocales
	pgDetalle.Initialize
	B4XPages.AddPage("detalle",pgDetalle)
End Sub

Public Sub CargarPedidosLocales
	clvPedidos.Clear ' Limpiamos la lista antes de cargar
    
	Dim rs As ResultSet = B4XPages.MainPage.sql1.ExecQuery("SELECT * FROM pedidos ORDER BY id DESC")
    
	Do While rs.NextRow
		Dim id As Int = rs.GetInt("id")
		Dim cliente As String = rs.GetString("cliente")
		Dim estado As String = rs.GetString("estado")
		' Dim foto As String = rs.GetString("foto_path")
        
		Dim p As B4XView = xui.CreatePanel("")
		p.SetLayoutAnimated(0, 0, 0, clvPedidos.AsView.Width, 60dip)
        
		' Color según el estado
		Dim colorFondo As Int
		If estado = "Sincronizado" Then
			colorFondo = xui.Color_ARGB(255, 200, 255, 200) ' Verde clarito
		Else
			colorFondo = xui.Color_White ' Blanco por defecto para pendientes
		End If
		
		p.Color = colorFondo
		p.SetColorAndBorder(colorFondo, 1dip, xui.Color_LightGray, 5dip)
        
		Dim lbl As Label
		lbl.Initialize("")
		Dim xlbl As B4XView = lbl
		p.AddView(xlbl, 10dip, 0, p.Width - 20dip, p.Height)
        
		xlbl.Text = $"ID: ${id} | ${cliente}     [${estado}]"$
		xlbl.TextColor = xui.Color_Black
		xlbl.SetTextAlignment("CENTER", "LEFT")
		xlbl.Font = xui.CreateDefaultFont(16)
        
		clvPedidos.Add(p, id)
	Loop
	rs.Close
End Sub

Sub clvPedidos_ItemClick (Index As Int, Value As Object)
	Dim idPedido As Int = Value
    
	B4XPages.ShowPageAndRemovePreviousPages("detalle")
	pgDetalle.CargarDetalle(idPedido)
End Sub

Sub btnsincronizar_Click
	Try
		If VerificarInternet = False Then
			xui.MsgboxAsync("Conéctese a Internet para sincronizar", "Sin Conexión")
			Return
		End If
		If File.Exists(File.DirInternal, "token_auth.txt") = False Then
			xui.MsgboxAsync("No hay token de sesión. Inicie sesión de nuevo.", "Error")
			Return
		End If
		' 1. Leer el token guardado
		Dim token As String = File.ReadString(File.DirInternal, "token_auth.txt")
    
		Dim rs As ResultSet = B4XPages.MainPage.sql1.ExecQuery("SELECT * FROM pedidos WHERE estado = 'Pendiente'")
		Dim totalSincronizados As Int = 0
	
		Do While rs.NextRow
			Dim idPedido As Int = rs.GetInt("id")
		
			' 3. Convertir la foto a String (Base64) para enviarla en el JSON
			Dim fotoBase64 As String = ""
			Dim nombreFoto As String = rs.GetString("foto_path")
			Dim rp As RuntimePermissions
			Dim dir As String = rp.GetSafeDirDefaultExternal("")
        
			If nombreFoto <> "" And File.Exists(dir, nombreFoto) Then
				Dim su As StringUtils
				Dim out As OutputStream
				out.InitializeToBytesArray(0)
				' Cargamos el archivo y lo comprimimos
				Dim bmp As B4XBitmap = xui.LoadBitmapResize(dir, nombreFoto, 400, 400, True)
				bmp.WriteToStream(out, 50, "JPEG")
				fotoBase64 = su.EncodeBase64(out.ToBytesArray)
			End If
		
			Dim Job As HttpJob
			Job.Initialize("", Me)
        
			' 4. Preparar el JSON para la API
			Dim mapa As Map = CreateMap( _
            "cliente": rs.GetString("cliente"), _
            "telefono": rs.GetString("telefono"), _
            "direccion": rs.GetString("direccion"), _
            "detalle": rs.GetString("detalle"), _
            "tipo_pago": rs.GetString("tipo_pago"), _
            "latitud": rs.GetDouble("latitud"), _
            "longitud": rs.GetDouble("longitud"), _
            "fecha": rs.GetString("fecha"), _
            "foto": fotoBase64 _
        )
        
			Dim jg As JSONGenerator
			jg.Initialize(mapa)
			Log("Enviando JSON: " & jg.ToString)
        
			' 4. Configurar la petición con el TOKEN
			Job.PostString("https://api-pedidos-o0t9.onrender.com/orders", jg.ToString)
			Job.GetRequest.SetContentType("application/json")
			Job.GetRequest.SetHeader("Authorization", "Bearer " & token)
        
			Wait For (Job) JobDone(j As HttpJob)
        
			If j.Success Then
				' 5. actualización del estado local
				B4XPages.MainPage.sql1.ExecNonQuery("UPDATE pedidos SET estado = 'Sincronizado' WHERE id = " & idPedido)
				totalSincronizados = totalSincronizados + 1
				Log("Pedido " & idPedido & " sincronizado con éxito")
			Else
				Log("Error en pedido " & idPedido & ": " & j.ErrorMessage)
				xui.MsgboxAsync(j.ErrorMessage, "Proceso Finalizado")
			End If
			j.Release
		Loop
		rs.Close
		xui.MsgboxAsync("Se sincronizaron " & totalSincronizados & " pedidos.", "Proceso Finalizado")
		CargarPedidosLocales ' Refrescar la lista
	Catch
		Log(LastException)
		xui.MsgboxAsync("Error al verificar la conexión", "Error")
	End Try
End Sub

Sub btnregresar_Click
	B4XPages.ShowPage("registro")
End Sub

Private Sub VerificarInternet As Boolean
	Dim n As JavaObject
	n.InitializeContext
	Dim cm As JavaObject = n.RunMethod("getSystemService", Array("connectivity"))
	Dim activeNetwork As JavaObject = cm.RunMethod("getActiveNetworkInfo", Null)
    
	If activeNetwork.IsInitialized Then
		Return activeNetwork.RunMethod("isConnected", Null)
	Else
		Return False
	End If
End Sub
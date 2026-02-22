B4A=true
Group=Default Group
ModulesStructureVersion=1
Type=Class
Version=13.4
@EndOfDesignText@
Sub Class_Globals
	Private Root As B4XView 'ignore
	Private xui As XUI 'ignore
	Private lblid As Label
	Private lblnombre As Label
	Private lbltelefono As Label
	Private lbldireccion As Label
	Private lbldetalle As Label
	Private lblpago As Label
	Private lblubicacion As Label
	Private lblfecha As Label
	Private ivimg As ImageView
End Sub

'You can add more parameters here.
Public Sub Initialize As Object
	Return Me
End Sub

'This event will be called once, before the page becomes visible.
Private Sub B4XPage_Created (Root1 As B4XView)
	Root = Root1
	'load the layout to Root
	Root.LoadLayout("detalle")
	
End Sub

Public Sub CargarDetalle(id As Int)
	Dim rs As ResultSet = B4XPages.MainPage.sql1.ExecQuery2("SELECT * FROM pedidos WHERE id = ?", Array As String(id))
    
	If rs.NextRow Then
		lblid.Text = rs.GetInt("id")
		lblnombre.Text = rs.GetString("cliente")
		lbltelefono.Text = rs.GetString("telefono")
		lbldireccion.Text=rs.GetString("direccion")
		lbldetalle.Text=rs.GetString("detalle")
		lblpago.Text=rs.GetString("tipo_pago")
		lblubicacion.Text=rs.GetString("latitud") & " " & rs.GetString("longitud")
		lblfecha.Text=rs.GetString("fecha")
        
		' CARGAR LA FOTO
		Dim nombreFoto As String = rs.GetString("foto_path")
		Dim rp As RuntimePermissions
		Dim directorio As String = rp.GetSafeDirDefaultExternal("")
        
		If nombreFoto <> "" And File.Exists(directorio, nombreFoto) Then
			ivimg.Bitmap = xui.LoadBitmapResize(directorio, nombreFoto, ivimg.Width, ivimg.Height, True)
		Else
			ivimg.Bitmap = Null ' O una imagen por defecto
		End If
	End If
	rs.Close
End Sub

Sub btnregresar_Click
	B4XPages.ShowPage("pedidos")
End Sub
/// URL de lista M3U (`get.php`) a partir del servidor del proveedor y las
/// credenciales del usuario (modo white-label: el cliente solo teclea
/// usuario y contraseña).
String buildXtreamListUrl(String server, String user, String pass) {
  var s = server.trim();
  if (!s.startsWith('http://') && !s.startsWith('https://')) {
    s = 'http://$s';
  }
  s = s.replaceAll(RegExp(r'/+$'), '');
  final u = Uri.encodeQueryComponent(user.trim());
  final p = Uri.encodeQueryComponent(pass.trim());
  return '$s/get.php?username=$u&password=$p&type=m3u_plus&output=ts';
}

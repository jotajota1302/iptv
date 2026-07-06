/// Método de desentrelazado para la TV en directo entrelazada.
///
/// - `bwdif`: estándar (rápido, buena calidad), el que veníamos usando.
/// - `estdif`: puede verse mejor en movimiento SEGÚN el contenido (sidegrade,
///   no un salto garantizado); recomendable comparar A/B en cada canal.
///
/// Ambos son LGPL, así que van en la build comercial. El neuronal `nnedi` NO se
/// incluye: es GPL (no distribuible en la build LGPL) y muy pesado en CPU.
enum Deinterlacer {
  bwdif('Estándar (bwdif)'),
  estdif('Detalle (estdif)');

  final String label;
  const Deinterlacer(this.label);
}

/// Valor de `hwdec` que debe fijar el [VideoController] al crearse, o `null`
/// para dejar su default (`auto`).
///
/// En directo entrelazado con aceleración GPU hace falta `auto-copy`: se
/// decodifica por GPU pero los fotogramas se copian a CPU, donde los filtros
/// de desentrelazado (bwdif/estdif) sí pueden actuar. Con `auto` (d3d11va
/// directo) los fotogramas se quedan en GPU y el filtro no los ve → peine.
///
/// IMPORTANTE: este valor debe ir en `VideoControllerConfiguration.hwdec`.
/// Fijarlo solo con `setProperty('hwdec', ...)` no basta: el VideoController
/// de media_kit escribe su propio `hwdec` de forma asíncrona al crearse y,
/// según el timing, PISA lo fijado a mano (por eso el desentrelazado
/// funcionaba unas veces sí y otras no).
String? initialHwdec({
  required bool live,
  required bool deinterlace,
  required bool hwAccel,
}) {
  if (live && deinterlace && hwAccel) return 'auto-copy';
  return null;
}

/// Cadenas `vf` candidatas para [d], en orden de preferencia. El controlador las
/// prueba una a una verificando con lectura de vuelta de la propiedad `vf`: la
/// primera que mpv acepte gana. SIEMPRE terminan en `bwdif` simple como red de
/// seguridad, de modo que un método no soportado por esta libmpv nunca deja la
/// imagen sin filtro. Se prefiere el modo campo (send_field/field) para menos
/// peine en movimiento.
List<String> deinterlacerCandidates(Deinterlacer d) {
  switch (d) {
    case Deinterlacer.estdif:
      return const [
        'estdif=mode=field',
        'estdif',
        'bwdif=mode=send_field',
        'bwdif',
      ];
    case Deinterlacer.bwdif:
      return const [
        'bwdif=mode=send_field',
        'bwdif=mode=field',
        'bwdif',
      ];
  }
}

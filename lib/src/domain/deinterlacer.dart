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

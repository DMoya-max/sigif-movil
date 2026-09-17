import 'package:flutter/material.dart';

/// Paleta de colores de SIGIF replicada del tema web (static/css/style1.css
/// y PDFs con azul/verde SIGIF).
class ColoresSigif {
  ColoresSigif._();

  // Marca
  static const Color azulPrimario = Color(0xFF3A56E4);
  static const Color azulSecundario = Color(0xFF5C7CFA);
  static const Color navy = Color(0xFF1E2A44);
  static const Color verde = Color(0xFF05A77B);

  // Sidebar / navegación
  static const Color sidebarBg = Color(0xFF222938);
  static const Color sidebarTexto = Color(0xFFA3B1CC);

  // Fondo y superficies
  static const Color fondo = Color(0xFFF5F6FA);
  static const Color tarjeta = Color(0xFFFFFFFF);
  static const Color borde = Color(0xFFE2E8F0);

  // Texto
  static const Color textoOscuro = Color(0xFF1A202C);
  static const Color textoCuerpo = Color(0xFF2D3748);
  static const Color textoMitigado = Color(0xFF64748B);

  // Estados semánticos
  static const Color exito = Color(0xFF059669);
  static const Color exitoSuave = Color(0xFFECFDF5);
  static const Color peligro = Color(0xFFDC2626);
  static const Color peligroGradA = Color(0xFFF56565);
  static const Color peligroGradB = Color(0xFFC53030);
  static const Color peligroSuave = Color(0xFFFFF1F2);
  static const Color advertencia = Color(0xFFF59E0B);
  static const Color advertenciaGradA = Color(0xFFFFFBF5);
  static const Color advertenciaGradB = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF0369A1);
  static const Color infoSuave = Color(0xFFE0F2FE);

  static const LinearGradient gradienteLogin = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF222938), Color(0xFFF5F6FA)],
  );

  static const LinearGradient gradienteAzul = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3A56E4), Color(0xFF5C7CFA)],
  );

  static const LinearGradient gradienteLogout = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF56565), Color(0xFFC53030)],
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData tema() {
    final scheme = ColorScheme.fromSeed(
      seedColor: ColoresSigif.azulPrimario,
      primary: ColoresSigif.azulPrimario,
      secondary: ColoresSigif.azulSecundario,
      error: ColoresSigif.peligro,
      surface: ColoresSigif.tarjeta,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ColoresSigif.fondo,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: ColoresSigif.tarjeta,
        foregroundColor: ColoresSigif.textoOscuro,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ColoresSigif.textoOscuro,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: const CardThemeData(
        color: ColoresSigif.tarjeta,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: ColoresSigif.borde),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ColoresSigif.azulPrimario, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ColoresSigif.azulPrimario,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: ColoresSigif.azulPrimario),
      ),
      dividerTheme: const DividerThemeData(color: ColoresSigif.borde, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: ColoresSigif.infoSuave,
        labelStyle: const TextStyle(color: ColoresSigif.info, fontSize: 12, fontWeight: FontWeight.w600),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}
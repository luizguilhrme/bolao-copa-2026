import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'cores.dart';

// =============================================================================
// dialogos.dart — helpers de UI compartilhados entre telas
//
// Funções top-level para exibir SnackBars padronizados e widgets de diálogo
// reutilizados em mais de uma tela.
// =============================================================================

// -----------------------------------------------------------------------------
// SnackBars
// -----------------------------------------------------------------------------

/// Exibe um SnackBar de sucesso (fundo verde).
void mostrarSnackBarSucesso(BuildContext context, String mensagem,
    {Duration duration = const Duration(seconds: 3)}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(mensagem, style: GoogleFonts.hankenGrotesk()),
    backgroundColor: Cores.verdePrincipal,
    behavior: SnackBarBehavior.floating,
    duration: duration,
  ));
}

/// Exibe um SnackBar de erro (fundo vermelho).
void mostrarSnackBarErro(BuildContext context, String mensagem,
    {Duration duration = const Duration(seconds: 6)}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(mensagem, style: GoogleFonts.hankenGrotesk()),
    backgroundColor: Cores.error,
    behavior: SnackBarBehavior.floating,
    duration: duration,
  ));
}

/// Exibe um SnackBar informativo (fundo azul terciário).
void mostrarSnackBarInfo(BuildContext context, String mensagem,
    {Duration duration = const Duration(seconds: 3)}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(mensagem, style: GoogleFonts.hankenGrotesk()),
    backgroundColor: Cores.azulTerciario,
    behavior: SnackBarBehavior.floating,
    duration: duration,
  ));
}

// -----------------------------------------------------------------------------
// Diálogos reutilizados em múltiplas telas
// -----------------------------------------------------------------------------

/// Dialog de seleção de ambiente (Produção / Teste) para popular jogos.
/// Retorna `'producao'`, `'teste'` ou `null` (cancelado).
///
/// Usado em: tela_admin_definicoes.dart
class DialogAmbiente extends StatelessWidget {
  const DialogAmbiente({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Cores.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.cloud_upload_outlined, color: Cores.verdePrincipal),
          const SizedBox(width: 8),
          Text(
            'Popular jogos',
            style: GoogleFonts.anybody(
              fontWeight: FontWeight.w800,
              color: Cores.onSurface,
            ),
          ),
        ],
      ),
      content: Text(
        'Escolha o ambiente. Os 104 jogos serão gravados no Firestore '
        'sobrescrevendo os dados atuais.',
        style: GoogleFonts.hankenGrotesk(
          fontSize: 14,
          color: Cores.onSurfaceVariant,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancelar',
            style: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant),
          ),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.science_outlined, size: 18),
          label: Text(
            'Teste',
            style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Cores.azulTerciario,
            side: const BorderSide(color: Cores.azulTerciario),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.of(context).pop('teste'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.public_rounded, size: 18),
          label: Text(
            'Produção',
            style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Cores.verdePrincipal,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.of(context).pop('producao'),
        ),
      ],
    );
  }
}

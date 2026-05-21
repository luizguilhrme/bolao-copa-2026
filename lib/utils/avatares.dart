import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'biblioteca.dart';
import 'cores.dart';

class Jogador {
  final String id;
  final String nome;
  final String pais;
  const Jogador(this.id, this.nome, this.pais);
}

const kJogadores = [
  Jogador('messi', 'Messi', 'Argentina'),
  Jogador('cr7', 'Cristiano Ronaldo', 'Portugal'),
  Jogador('mbappe', 'Mbappé', 'France'),
  Jogador('vinicius', 'Vinicius Jr.', 'Brazil'),
  Jogador('neymar', 'Neymar Jr.', 'Brazil'),
  Jogador('paqueta', 'Paquetá', 'Brazil'),
  Jogador('haaland', 'Haaland', 'Norway'),
  Jogador('bellingham', 'Bellingham', 'England'),
  Jogador('salah', 'Salah', 'Egypt'),
  Jogador('yamal', 'Yamal', 'Spain'),
  Jogador('modric', 'Modrić', 'Croatia'),
  Jogador('ochoa', 'Ochoa', 'Mexico'),
];

// Widget de avatar circular reutilizável.
// Exibe a foto do jogador se disponível, senão mostra a inicial do nome.
class WidgetAvatar extends StatelessWidget {
  const WidgetAvatar({
    super.key,
    required this.avatarId,
    required this.nome,
    required this.tamanho,
    this.corFundo = Cores.verdePrincipal,
    this.corTexto = Colors.white,
    this.borderColor,
    this.borderWidth = 2.0,
  });

  final String? avatarId;
  final String nome;
  final double tamanho;
  final Color corFundo;
  final Color corTexto;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final inicial = nome.isNotEmpty ? nome[0].toUpperCase() : '?';

    Widget conteudo = avatarId != null
        ? Image.asset(
            'assets/avatares/$avatarId.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _FundoInicial(corFundo: corFundo, corTexto: corTexto, inicial: inicial, tamanho: tamanho),
          )
        : _FundoInicial(corFundo: corFundo, corTexto: corTexto, inicial: inicial, tamanho: tamanho);

    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderColor != null ? Border.all(color: borderColor!, width: borderWidth) : null,
      ),
      child: ClipOval(child: conteudo),
    );
  }
}

class _FundoInicial extends StatelessWidget {
  const _FundoInicial({
    required this.corFundo,
    required this.corTexto,
    required this.inicial,
    required this.tamanho,
  });

  final Color corFundo;
  final Color corTexto;
  final String inicial;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: corFundo,
      child: Center(
        child: Text(
          inicial,
          style: GoogleFonts.anybody(
            fontSize: tamanho * 0.44,
            fontWeight: FontWeight.w800,
            color: corTexto,
          ),
        ),
      ),
    );
  }
}

// Card de seleção de avatar usado no setup e no seletor do perfil.
class CardAvatar extends StatelessWidget {
  const CardAvatar({
    super.key,
    required this.jogador,
    required this.selecionado,
    required this.onTap,
  });

  final Jogador jogador;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selecionado ? const Color(0xFFE8F5E9) : Cores.surface,
          border: Border.all(
            color: selecionado ? Cores.verdePrincipal : Cores.outlineVariant,
            width: selecionado ? 2.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/avatares/${jogador.id}.jpg',
                    width: 62,
                    height: 62,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 62,
                      height: 62,
                      color: Cores.surfaceContainerHigh,
                      child: const Icon(Icons.person_rounded, size: 38, color: Cores.onSurfaceVariant),
                    ),
                  ),
                ),
                if (selecionado)
                  Container(
                    decoration: const BoxDecoration(
                      color: Cores.verdePrincipal,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                jogador.nome,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Cores.onSurface,
                ),
              ),
            ),
            Bandeira(jogador.pais, tamanho: 14),
          ],
        ),
      ),
    );
  }
}

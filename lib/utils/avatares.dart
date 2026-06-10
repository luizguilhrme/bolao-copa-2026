import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// Fotos oficiais FIFA da seleção brasileira convocada para a Copa 2026
// (ensaio de 04/06/2026 em Morristown) + Ancelotti. Neymar, Vini Jr. e
// Paquetá usam o sufixo 2026 para não colidir com os avatares deles em
// "Principais". Alex Sandro (#6) não tem retrato individual na galeria FIFA.
const kJogadoresBrasil2026 = [
  Jogador('alisson', 'Alisson', 'Brazil'),
  Jogador('ederson', 'Ederson', 'Brazil'),
  Jogador('weverton', 'Weverton', 'Brazil'),
  Jogador('neymar2026', 'Neymar Jr.', 'Brazil'),
  Jogador('marquinhos', 'Marquinhos', 'Brazil'),
  Jogador('danilo', 'Danilo', 'Brazil'),
  Jogador('casemiro', 'Casemiro', 'Brazil'),
  Jogador('vini2026', 'Vinicius Jr.', 'Brazil'),
  Jogador('raphinha', 'Raphinha', 'Brazil'),
  Jogador('bremer', 'Bremer', 'Brazil'),
  Jogador('brunog', 'Bruno Guimarães', 'Brazil'),
  Jogador('fabinho', 'Fabinho', 'Brazil'),
  Jogador('paqueta2026', 'Paquetá', 'Brazil'),
  Jogador('martinelli', 'Martinelli', 'Brazil'),
  Jogador('wesley', 'Wesley', 'Brazil'),
  Jogador('douglassantos', 'Douglas Santos', 'Brazil'),
  Jogador('leopereira', 'Léo Pereira', 'Brazil'),
  Jogador('ibanez', 'Ibañez', 'Brazil'),
  Jogador('gabrielmagalhaes', 'Gabriel Magalhães', 'Brazil'),
  Jogador('danilosantos', 'Danilo Santos', 'Brazil'),
  Jogador('luizhenrique', 'Luiz Henrique', 'Brazil'),
  Jogador('rayan', 'Rayan', 'Brazil'),
  Jogador('endrick', 'Endrick', 'Brazil'),
  Jogador('matheuscunha', 'Matheus Cunha', 'Brazil'),
  Jogador('igorthiago', 'Igor Thiago', 'Brazil'),
  // Técnico da seleção — bandeira do Brasil porque 'Italy' não tem
  // mapeamento em isoDe() (não está entre as 48 classificadas)
  Jogador('ancelotti', 'Ancelotti', 'Brazil'),
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
// Suporta "avatar secreto": se existir um arquivo *2.jpg, um long-press
// anima um flip 3D revelando a foto alternativa e auto-seleciona ela.
class CardAvatar extends StatefulWidget {
  const CardAvatar({
    super.key,
    required this.jogador,
    required this.avatarSelecionadoId,
    required this.onTap,
  });

  final Jogador jogador;
  // ID completo do avatar atualmente selecionado pelo pai (ex: 'paqueta' ou 'paqueta2').
  final String? avatarSelecionadoId;
  final void Function(String avatarId) onTap;

  @override
  State<CardAvatar> createState() => _CardAvatarState();
}

class _CardAvatarState extends State<CardAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _temAlternativo = false;

  bool get _selecionado =>
      widget.avatarSelecionadoId == widget.jogador.id ||
      widget.avatarSelecionadoId == '${widget.jogador.id}2';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    // Se o avatar alternativo já estava selecionado, inicia no estado virado.
    if (widget.avatarSelecionadoId == '${widget.jogador.id}2') {
      _ctrl.value = 1.0;
    }
    _verificarAlternativo();
  }

  Future<void> _verificarAlternativo() async {
    try {
      await rootBundle.load('assets/avatares/${widget.jogador.id}2.jpg');
      if (mounted) setState(() => _temAlternativo = true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() {
    final id = _ctrl.value >= 0.5 ? '${widget.jogador.id}2' : widget.jogador.id;
    widget.onTap(id);
  }

  void _onLongPress() {
    if (!_temAlternativo) {
      // Sem alternativo: long-press se comporta como tap normal.
      widget.onTap(widget.jogador.id);
      return;
    }
    HapticFeedback.mediumImpact();
    if (_ctrl.value < 0.5) {
      _ctrl.forward().then((_) {
        if (mounted) widget.onTap('${widget.jogador.id}2');
      });
    } else {
      _ctrl.reverse().then((_) {
        if (mounted) widget.onTap(widget.jogador.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      onLongPress: _onLongPress,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final t = _anim.value;
          final mostrarAlternativo = t >= 0.5;
          // Fase 1 (0→0.5): frente gira de 0° até 90° (some).
          // Fase 2 (0.5→1.0): verso entra de -90° até 0° (aparece).
          final angle = mostrarAlternativo ? (t - 1.0) * pi : t * pi;
          final imageId = mostrarAlternativo ? '${widget.jogador.id}2' : widget.jogador.id;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: _buildConteudo(imageId: imageId),
          );
        },
      ),
    );
  }

  Widget _buildConteudo({required String imageId}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: _selecionado ? const Color(0xFFE8F5E9) : Cores.surface,
        border: Border.all(
          color: _selecionado ? Cores.verdePrincipal : Cores.outlineVariant,
          width: _selecionado ? 2.5 : 1,
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
                  'assets/avatares/$imageId.jpg',
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
              if (_selecionado)
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
              widget.jogador.nome,
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
          Bandeira(widget.jogador.pais, tamanho: 14),
        ],
      ),
    );
  }
}

// Grade de seleção de avatar com abas lado a lado (PRINCIPAIS / BRASIL 2026).
// Abre na aba do avatar atualmente selecionado. Não rola sozinha — deve ser
// colocada dentro de um scroll do chamador (SingleChildScrollView, ListView etc).
class GradeAvataresSecionada extends StatefulWidget {
  const GradeAvataresSecionada({
    super.key,
    required this.avatarSelecionadoId,
    required this.onTap,
  });

  final String? avatarSelecionadoId;
  final void Function(String avatarId) onTap;

  @override
  State<GradeAvataresSecionada> createState() => _GradeAvataresSecionadaState();
}

class _GradeAvataresSecionadaState extends State<GradeAvataresSecionada> {
  late bool _abaPrincipais;

  @override
  void initState() {
    super.initState();
    // Abre na aba do avatar já selecionado
    _abaPrincipais = !kJogadoresBrasil2026
        .any((j) => widget.avatarSelecionadoId == j.id);
  }

  Widget _grade(List<Jogador> jogadores) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: jogadores.length,
      itemBuilder: (context, index) => CardAvatar(
        jogador: jogadores[index],
        avatarSelecionadoId: widget.avatarSelecionadoId,
        onTap: widget.onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _BotaoAbaAvatar(
                label: 'PRINCIPAIS',
                ativo: _abaPrincipais,
                onTap: () => setState(() => _abaPrincipais = true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _BotaoAbaAvatar(
                label: 'BRASIL 2026',
                comBandeira: true,
                ativo: !_abaPrincipais,
                onTap: () => setState(() => _abaPrincipais = false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _grade(_abaPrincipais ? kJogadores : kJogadoresBrasil2026),
      ],
    );
  }
}

class _BotaoAbaAvatar extends StatelessWidget {
  const _BotaoAbaAvatar({
    required this.label,
    required this.ativo,
    required this.onTap,
    this.comBandeira = false,
  });

  final String label;
  final bool ativo;
  final VoidCallback onTap;
  final bool comBandeira;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: ativo ? Cores.verdePrincipal : Cores.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.anybody(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ativo ? Colors.white : Cores.onSurfaceVariant,
              ),
            ),
            if (comBandeira) ...[
              const SizedBox(width: 6),
              const Bandeira('Brazil', tamanho: 14),
            ],
          ],
        ),
      ),
    );
  }
}

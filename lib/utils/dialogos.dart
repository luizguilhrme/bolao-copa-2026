import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'biblioteca.dart';
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

// -----------------------------------------------------------------------------
// Modelo de dados de jogador — compartilhado por tela_palpites_especiais e
// tela_admin_especiais
// -----------------------------------------------------------------------------

class JogadorData {
  const JogadorData({
    required this.nome,
    required this.posicao,
    required this.clube,
    required this.selecaoNome,
    required this.selecaoNomePt,
  });

  final String nome;
  final String posicao;
  final String clube;
  final String selecaoNome;
  final String selecaoNomePt;
}

// -----------------------------------------------------------------------------
// Bottom sheet de seleção de jogador — compartilhado por tela_palpites_especiais
// e tela_admin_especiais. [cor] define a cor de destaque.
// -----------------------------------------------------------------------------

class BottomSheetJogadores extends StatefulWidget {
  const BottomSheetJogadores({
    super.key,
    required this.titulo,
    required this.jogadores,
    required this.selecionadoAtual,
    required this.onSelecionado,
    required this.cor,
    this.apenasGoleiros = false,
  });

  final String titulo;
  final List<JogadorData> jogadores;
  final String? selecionadoAtual;
  final void Function(String?) onSelecionado;
  final Color cor;
  final bool apenasGoleiros;

  @override
  State<BottomSheetJogadores> createState() => _BottomSheetJogadoresState();
}

class _BottomSheetJogadoresState extends State<BottomSheetJogadores> {
  String _busca = '';
  String? _filtroSelecao;
  final _ctrlBusca = TextEditingController();

  late final List<(String nome, String nomePt)> _selecoes;

  @override
  void initState() {
    super.initState();
    final base = widget.apenasGoleiros
        ? widget.jogadores.where((j) => j.posicao == 'GOL').toList()
        : widget.jogadores;
    final vistas = <String>{};
    final list = <(String, String)>[];
    for (final j in base) {
      if (vistas.add(j.selecaoNome)) list.add((j.selecaoNome, j.selecaoNomePt));
    }
    _selecoes = list;
  }

  @override
  void dispose() {
    _ctrlBusca.dispose();
    super.dispose();
  }

  String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[áàãâä]'), 'a')
      .replaceAll(RegExp(r'[éèêë]'), 'e')
      .replaceAll(RegExp(r'[íìîï]'), 'i')
      .replaceAll(RegExp(r'[óòõôö]'), 'o')
      .replaceAll(RegExp(r'[úùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll('ñ', 'n');

  @override
  Widget build(BuildContext context) {
    final porPosicao = widget.apenasGoleiros
        ? widget.jogadores.where((j) => j.posicao == 'GOL').toList()
        : widget.jogadores;
    final porSelecao = _filtroSelecao == null
        ? porPosicao
        : porPosicao.where((j) => j.selecaoNome == _filtroSelecao).toList();
    final buscaNorm = _norm(_busca);
    final filtrados = buscaNorm.isEmpty
        ? porSelecao
        : porSelecao.where((j) => _norm(j.nome).contains(buscaNorm)).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Cores.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Cores.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    widget.titulo.toUpperCase(),
                    style: GoogleFonts.anybody(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Cores.onSurface,
                    ),
                  ),
                  if (widget.apenasGoleiros) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.cor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'GOLEIROS',
                        style: GoogleFonts.anybody(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: widget.cor,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _ctrlBusca,
                autofocus: false,
                onChanged: (v) => setState(() => _busca = v),
                decoration: InputDecoration(
                  hintText: 'Buscar por nome...',
                  hintStyle: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant),
                  prefixIcon: const Icon(Icons.search_rounded, color: Cores.onSurfaceVariant),
                  filled: true,
                  fillColor: Cores.surfaceContainer,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Cores.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: widget.cor, width: 2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildDropdownSelecao(),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${filtrados.length} jogador${filtrados.length != 1 ? 'es' : ''}',
                  style: GoogleFonts.hankenGrotesk(fontSize: 12, color: Cores.onSurfaceVariant),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtrados.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum resultado',
                        style: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtrados.length,
                      itemBuilder: (_, i) {
                        final j = filtrados[i];
                        final selecionado = widget.selecionadoAtual == j.nome;
                        return ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Cores.outlineVariant),
                            ),
                            child: Bandeira(j.selecaoNome, tamanho: 36),
                          ),
                          title: Text(
                            j.nome,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 15,
                              fontWeight: selecionado ? FontWeight.w700 : FontWeight.w400,
                              color: selecionado ? widget.cor : Cores.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            j.clube != '-'
                                ? '${j.selecaoNomePt} · ${j.clube}'
                                : j.selecaoNomePt,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12,
                              color: Cores.onSurfaceVariant,
                            ),
                          ),
                          trailing: selecionado
                              ? Icon(Icons.check_circle, color: widget.cor, size: 22)
                              : null,
                          tileColor: selecionado
                              ? widget.cor.withValues(alpha: 0.08)
                              : null,
                          onTap: () => widget.onSelecionado(j.nome),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownSelecao() {
    final ativo = _filtroSelecao != null;
    return PopupMenuButton<String>(
      initialValue: _filtroSelecao ?? '',
      color: Cores.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      constraints: const BoxConstraints(maxHeight: 320),
      onSelected: (v) => setState(() => _filtroSelecao = v.isEmpty ? null : v),
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          value: '',
          child: Row(
            children: [
              const Icon(Icons.public_rounded, size: 20, color: Cores.onSurfaceVariant),
              const SizedBox(width: 10),
              Text(
                'Todos',
                style: GoogleFonts.anybody(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Cores.onSurface,
                ),
              ),
            ],
          ),
        ),
        ..._selecoes.map((s) => PopupMenuItem<String>(
              value: s.$1,
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: Bandeira(s.$1, tamanho: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(s.$2, style: GoogleFonts.hankenGrotesk(fontSize: 14, color: Cores.onSurface)),
                ],
              ),
            )),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
        decoration: BoxDecoration(
          color: ativo ? widget.cor.withValues(alpha: 0.08) : Cores.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: ativo ? widget.cor : Cores.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!ativo)
              Text(
                'Todos',
                style: GoogleFonts.anybody(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Cores.onSurfaceVariant,
                ),
              )
            else ...[
              Container(
                width: 18,
                height: 18,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: Bandeira(_filtroSelecao!, tamanho: 18),
              ),
              const SizedBox(width: 5),
              Text(
                _selecoes.firstWhere((s) => s.$1 == _filtroSelecao).$2,
                style: GoogleFonts.anybody(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: widget.cor,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: ativo ? widget.cor : Cores.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
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

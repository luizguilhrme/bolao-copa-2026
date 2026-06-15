import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../models/grupo.dart';
import '../models/jogo.dart';
import '../models/palpite.dart';
import '../models/usuario.dart';
import '../services/grupo_service.dart';
import '../services/usuario_service.dart';
import '../utils/arte_compartilhar.dart';
import '../utils/avatares.dart';
import '../utils/baixar_imagem_stub.dart'
    if (dart.library.js_interop) '../utils/baixar_imagem_web.dart';
import '../utils/biblioteca.dart';
import '../utils/cores.dart';
import '../utils/dialogos.dart';

// =============================================================================
// tela_compartilhar.dart — tela "Compartilhar" do story do palpite
//
// Aberta pelo card de resultado (tela de Palpites) em jogo encerrado com
// palpite e pontos calculados. Mostra o preview da arte Figurinha (9:16) e o
// card "O que mostrar" com toggles: Perfil (avatar + nome, com sub-toggle do
// @usuário), Posição no ranking (com chips dos bolões do usuário) e
// Pontuação. As escolhas são lembradas durante a sessão.
//
// COMPARTILHAR NO STORY captura o RepaintBoundary do preview como PNG
// (1080×1920) e entrega ao share_plus (share sheet nativo / Web Share API);
// no Web sem suporte a arquivos, cai no download direto. "Baixar imagem"
// (só Web) baixa o PNG sem passar pelo share sheet.
// =============================================================================

class TelaCompartilhar extends StatefulWidget {
  const TelaCompartilhar({
    super.key,
    required this.jogo,
    required this.palpite,
    required this.pontos,
    required this.pontosBase,
  });

  final Jogo jogo;
  final Palpite palpite;
  final int pontos;
  final int pontosBase;

  @override
  State<TelaCompartilhar> createState() => _TelaCompartilharState();
}

/// Posição do usuário em um dos seus bolões (critério oficial do ranking).
class _PosicaoGrupo {
  const _PosicaoGrupo({
    required this.grupo,
    required this.posicao,
    required this.total,
  });

  final Grupo grupo;
  final int posicao;
  final int total;
}

class _TelaCompartilharState extends State<TelaCompartilhar> {
  // Escolhas lembradas entre aberturas na mesma sessão
  static bool _prefPerfil = true;
  static bool _prefArroba = true;
  static bool _prefRanking = false;
  static bool _prefPontos = false;
  static String? _prefGrupoId;

  final _chaveArte = GlobalKey();
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  bool _gerando = false;

  Usuario? _usuario;
  List<_PosicaoGrupo> _posicoes = const [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  // Carrega o perfil e calcula a posição do usuário em cada bolão com o
  // mesmo critério da TelaRanking (ordenarRanking em biblioteca.dart).
  Future<void> _carregar() async {
    try {
      final results = await Future.wait([
        UsuarioService().buscarPorUid(_uid),
        GrupoService().buscarGruposDoUsuarioOnce(_uid),
        FirebaseFirestore.instance.collection('usuarios').get(),
        FirebaseFirestore.instance.collection('config').doc('copa2026').get(),
      ]);
      final usuario = results[0] as Usuario?;
      final grupos = results[1] as List<Grupo>;
      final todos = (results[2] as QuerySnapshot<Map<String, dynamic>>)
          .docs
          .map((d) => Usuario.fromMap(d.data()))
          .toList();
      final config =
          (results[3] as DocumentSnapshot<Map<String, dynamic>>).data();

      final posicoes = <_PosicaoGrupo>[];
      for (final grupo in grupos) {
        final membros =
            todos.where((u) => grupo.membros.contains(u.uid)).toList();
        ordenarRanking(
          membros,
          modoCopa: grupo.regra == 'copa',
          campeaoReal: config?['campeaoReal'] as String?,
          chuteiradeOuroReal: config?['chuteiradeOuroReal'] as String?,
        );
        final indice = membros.indexWhere((u) => u.uid == _uid);
        if (indice < 0) continue;
        posicoes.add(
          _PosicaoGrupo(
            grupo: grupo,
            posicao: indice + 1,
            total: membros.length,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _usuario = usuario;
        _posicoes = posicoes;
        if (_prefGrupoId == null ||
            !posicoes.any((p) => p.grupo.id == _prefGrupoId)) {
          _prefGrupoId = posicoes.firstOrNull?.grupo.id;
        }
      });
    } catch (_) {
      // Sem perfil/ranking a arte ainda funciona — os toggles ficam ocultos
    }
  }

  String get _arroba => _usuario?.email.split('@').first ?? '';

  _PosicaoGrupo? get _posicaoSelecionada =>
      _posicoes.where((p) => p.grupo.id == _prefGrupoId).firstOrNull;

  OpcoesArte get _opcoes => OpcoesArte(
    mostrarPerfil: _prefPerfil && _usuario != null,
    mostrarArroba: _prefArroba,
    mostrarPontos: _prefPontos,
    ranking:
        _prefRanking && _posicaoSelecionada != null
            ? RankingArte(
              nomeGrupo: _posicaoSelecionada!.grupo.nome,
              posicao: _posicaoSelecionada!.posicao,
              total: _posicaoSelecionada!.total,
            )
            : null,
  );

  // ─── Captura e compartilhamento ─────────────────────────────────────────────

  // Captura a arte (1080×1920 lógicos dentro do FittedBox) como PNG.
  // O RepaintBoundary mantém o tamanho lógico original — a escala do
  // preview é aplicada pelo FittedBox acima dele e não afeta a captura.
  Future<Uint8List> _capturarPng() async {
    // Garante que o frame do preview já foi pintado (fontes e bandeiras)
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _chaveArte.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final imagem = await boundary.toImage();
    try {
      final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);
      return dados!.buffer.asUint8List();
    } finally {
      imagem.dispose();
    }
  }

  String get _nomeArquivo => 'bolao_crava_ai_jogo_${widget.jogo.id}.png';

  Future<void> _compartilhar() async {
    setState(() => _gerando = true);

    final Uint8List bytes;
    try {
      bytes = await _capturarPng();
    } catch (_) {
      if (mounted) {
        setState(() => _gerando = false);
        mostrarSnackBarErro(context, 'Não foi possível gerar a imagem.');
      }
      return;
    }

    try {
      final resultado = await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/png', name: _nomeArquivo)],
        text: 'Meu palpite no Bolão - Crava aí! ⚽',
      );
      if (resultado.status == ShareResultStatus.unavailable) {
        await _baixarComoFallback(bytes);
      }
    } catch (_) {
      // Web Share API sem suporte a arquivos (ex: navegador desktop)
      // ou share sheet indisponível — tenta o download direto.
      await _baixarComoFallback(bytes);
    }

    if (mounted) setState(() => _gerando = false);
  }

  Future<void> _baixarComoFallback(Uint8List bytes) async {
    if (!kIsWeb) {
      if (mounted) {
        mostrarSnackBarErro(context, 'Não foi possível compartilhar a imagem.');
      }
      return;
    }
    try {
      await baixarImagem(bytes, _nomeArquivo);
      if (mounted) {
        mostrarSnackBarInfo(context, 'Imagem baixada — é só postar no story!');
      }
    } catch (_) {
      if (mounted) {
        mostrarSnackBarErro(context, 'Não foi possível compartilhar a imagem.');
      }
    }
  }

  // Download direto, sem share sheet (botão "Baixar imagem" — só Web)
  Future<void> _baixar() async {
    setState(() => _gerando = true);
    try {
      final bytes = await _capturarPng();
      await baixarImagem(bytes, _nomeArquivo);
      if (mounted) {
        mostrarSnackBarInfo(context, 'Imagem baixada — é só postar no story!');
      }
    } catch (_) {
      if (mounted) {
        mostrarSnackBarErro(context, 'Não foi possível baixar a imagem.');
      }
    }
    if (mounted) setState(() => _gerando = false);
  }

  // ─── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final jogo = widget.jogo;
    return Scaffold(
      backgroundColor: Cores.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Cores.verdePrincipal,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Compartilhar',
              style: GoogleFonts.anybody(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: Cores.onSurface,
              ),
            ),
            Text(
              '${nomePtDe(jogo.team1)} ${jogo.placar1}×${jogo.placar2} '
              '${nomePtDe(jogo.team2)}',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12.5,
                color: Cores.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
        children: [
          // Preview da arte em escala reduzida, mantendo a proporção 9:16
          Center(
            child: Container(
              width: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x38111C2D),
                    blurRadius: 30,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: 1080,
                      height: 1920,
                      child: RepaintBoundary(
                        key: _chaveArte,
                        child: ArteFigurinha(
                          jogo: jogo,
                          palpite: widget.palpite,
                          pontos: widget.pontos,
                          pontosBase: widget.pontosBase,
                          nome: _usuario?.nome ?? '',
                          arroba: _arroba,
                          avatarId: _usuario?.avatar,
                          opcoes: _opcoes,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pré-visualização do story · 9:16',
            textAlign: TextAlign.center,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 12.5,
              color: Cores.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // Card de seleção
          Container(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F111C2D),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'O que mostrar',
                        style: GoogleFonts.anybody(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: Cores.onSurface,
                        ),
                      ),
                      Text(
                        'opcional',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 12.5,
                          color: Cores.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // Perfil (avatar + nome) com sub-toggle do @usuário
                if (_usuario != null)
                  _ToggleRow(
                    leading: WidgetAvatar(
                      avatarId: _usuario!.avatar,
                      nome: _usuario!.nome,
                      tamanho: 40,
                      borderColor: Cores.outlineVariant,
                      borderWidth: 1.5,
                    ),
                    titulo: 'Perfil',
                    descricao: 'Avatar e nome · ${_usuario!.nome}',
                    ativo: _prefPerfil,
                    onChanged: (v) => setState(() => _prefPerfil = v),
                    filho: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F7F4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mostrar @usuário',
                                  style: GoogleFonts.anybody(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Cores.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '@$_arroba',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 12.5,
                                    color: Cores.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _Chave(
                            ativo: _prefArroba,
                            onChanged:
                                (v) => setState(() => _prefArroba = v),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Posição no ranking (só com bolão para mostrar)
                if (_posicoes.isNotEmpty)
                  _ToggleRow(
                    leading: const _PontoEmoji('🏆'),
                    titulo: 'Posição no ranking',
                    descricao: 'Mostra seu lugar em um dos seus bolões',
                    ativo: _prefRanking,
                    onChanged: (v) => setState(() => _prefRanking = v),
                    filho: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final p in _posicoes)
                          _ChipGrupo(
                            posicao: p,
                            selecionado: p.grupo.id == _prefGrupoId,
                            onTap:
                                () => setState(
                                  () => _prefGrupoId = p.grupo.id,
                                ),
                          ),
                      ],
                    ),
                  ),

                // Pontuação
                _ToggleRow(
                  leading: const _PontoEmoji('🎯'),
                  titulo: 'Pontuação',
                  descricao: 'Pontos que você fez nesse palpite',
                  ativo: _prefPontos,
                  onChanged: (v) => setState(() => _prefPontos = v),
                  ultimo: true,
                ),
              ],
            ),
          ),
        ],
      ),

      // Barra de ação fixa
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE6EAEE))),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _gerando ? null : _compartilhar,
                    style: FilledButton.styleFrom(
                      backgroundColor: Cores.verdePrincipal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon:
                        _gerando
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text(
                      'COMPARTILHAR NO STORY',
                      style: GoogleFonts.anybody(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                // No Android o share sheet já oferece salvar a imagem;
                // o download direto só faz sentido no Web
                if (kIsWeb)
                  TextButton(
                    onPressed: _gerando ? null : _baixar,
                    child: Text(
                      'Baixar imagem',
                      style: GoogleFonts.anybody(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: Cores.verdePrincipal,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Componentes da lista de seleção ─────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.leading,
    required this.titulo,
    required this.descricao,
    required this.ativo,
    required this.onChanged,
    this.filho,
    this.ultimo = false,
  });

  final Widget leading;
  final String titulo;
  final String descricao;
  final bool ativo;
  final ValueChanged<bool> onChanged;
  final Widget? filho; // exibido quando o toggle está ligado
  final bool ultimo;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border:
            ultimo
                ? null
                : const Border(
                  bottom: BorderSide(color: Color(0xFFECF0F3)),
                ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: GoogleFonts.anybody(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Cores.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        descricao,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 13,
                          height: 1.35,
                          color: Cores.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _Chave(ativo: ativo, onChanged: onChanged),
              ],
            ),
          ),
          if (ativo && filho != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 16),
              child: Align(alignment: Alignment.centerLeft, child: filho),
            ),
        ],
      ),
    );
  }
}

/// Switch padronizado da tela (verde quando ligado).
class _Chave extends StatelessWidget {
  const _Chave({required this.ativo, required this.onChanged});

  final bool ativo;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: ativo,
      onChanged: onChanged,
      activeTrackColor: Cores.verdePrincipal,
      inactiveTrackColor: Cores.outlineVariant,
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }
}

/// Quadradinho com emoji usado como leading das linhas sem avatar.
class _PontoEmoji extends StatelessWidget {
  const _PontoEmoji(this.emoji);

  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE6F2EA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 20)),
    );
  }
}

/// Chip de seleção do bolão cuja posição entra na arte ("3º Galera do Trabalho").
class _ChipGrupo extends StatelessWidget {
  const _ChipGrupo({
    required this.posicao,
    required this.selecionado,
    required this.onTap,
  });

  final _PosicaoGrupo posicao;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selecionado ? Cores.verdePrincipal : const Color(0xFFE6F2EA),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                selecionado ? Cores.verdePrincipal : const Color(0xFFD3E5DA),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${posicao.posicao}º',
              style: GoogleFonts.anybody(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: selecionado ? Colors.white : Cores.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              posicao.grupo.nome,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selecionado ? Colors.white : Cores.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

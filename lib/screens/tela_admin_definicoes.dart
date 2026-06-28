import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/jogo_service.dart';
import '../utils/avatares.dart';
import 'tela_admin_logs.dart';
import '../utils/biblioteca.dart';
import '../utils/cores.dart';
import '../utils/dialogos.dart';

class TelaAdminDefinicoes extends StatefulWidget {
  const TelaAdminDefinicoes({super.key});

  @override
  State<TelaAdminDefinicoes> createState() => _TelaAdminDefinicoesState();
}

class _TelaAdminDefinicoesState extends State<TelaAdminDefinicoes> {
  bool _populando = false;
  bool _mapeandoApi = false;
  bool _recalculando = false;
  // ignore: prefer_final_fields
  bool _recalculandoCopa = false;
  bool _limpando = false;
  bool _limpandoTeste = false;
  bool _travando = false;
  bool _adicionandoAoGrupo = false;
  bool? _palpitesTravados; // null = ainda carregando

  @override
  void initState() {
    super.initState();
    _carregarStatusTravamento();
  }

  Future<void> _carregarStatusTravamento() async {
    final doc = await FirebaseFirestore.instance
        .collection('config')
        .doc('copa2026')
        .get();
    if (!mounted) return;
    setState(() {
      _palpitesTravados =
          (doc.data()?['palpitesTravados'] as bool?) ?? false;
    });
  }

  Future<void> _alternarTravamento() async {
    final novoEstado = !(_palpitesTravados ?? false);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          novoEstado ? 'Travar palpites?' : 'Destravar palpites?',
          style: GoogleFonts.anybody(fontWeight: FontWeight.w700),
        ),
        content: Text(
          novoEstado
              ? 'Os palpites do Modo Copa e os Palpites Especiais ficarão '
                'visíveis para todos os participantes e não poderão mais ser '
                'alterados.'
              : 'Os palpites do Modo Copa e os Palpites Especiais voltarão a '
                'ficar ocultos e poderão ser editados pelos participantes.',
          style: GoogleFonts.hankenGrotesk(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCELAR',
                style: GoogleFonts.anybody(color: Cores.onSurfaceVariant)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor:
                    novoEstado ? Cores.error : Cores.verdePrincipal),
            child: Text(
              novoEstado ? 'TRAVAR' : 'DESTRAVAR',
              style: GoogleFonts.anybody(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _travando = true);
    try {
      await FirebaseFirestore.instance
          .collection('config')
          .doc('copa2026')
          .set({'palpitesTravados': novoEstado}, SetOptions(merge: true));
      if (mounted) {
        setState(() => _palpitesTravados = novoEstado);
        mostrarMensagem(
          context,
          novoEstado
              ? 'Palpites travados com sucesso.'
              : 'Palpites destravados com sucesso.',
        );
      }
    } catch (e) {
      if (mounted) mostrarMensagem(context, 'Erro: $e');
    } finally {
      if (mounted) setState(() => _travando = false);
    }
  }

  Future<void> _popularJogos() async {
    final ambiente = await showDialog<String>(
      context: context,
      builder: (_) => const DialogAmbiente(),
    );
    if (ambiente == null || !mounted) return;

    setState(() => _populando = true);
    try {
      await JogoService()
          .popularJogosNoFirestore(teste: ambiente == 'teste');
      if (mounted) {
        final label = ambiente == 'teste' ? 'TESTE' : 'PRODUÇÃO';
        mostrarMensagem(context, 'Jogos populados ($label)!');
      }
    } catch (e) {
      if (mounted) mostrarMensagem(context, 'Erro: $e');
    } finally {
      if (mounted) setState(() => _populando = false);
    }
  }

  Future<void> _mapearJogosApi() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Mapear jogos com a API?',
            style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
        content: Text(
          'Cruza os 104 jogos com a football-data.org (por data/hora UTC, fase e '
          'grupo) e grava o id da API em cada jogo. Também grava a primeira foto '
          'de classificação e artilharia.\n\n'
          'Executar uma vez — e novamente sempre que rodar "Popular Jogos".',
          style: GoogleFonts.hankenGrotesk(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCELAR',
                style: GoogleFonts.anybody(color: Cores.onSurfaceVariant)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Cores.azulTerciario),
            child: Text('MAPEAR',
                style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _mapeandoApi = true);
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      final result = await fn.httpsCallable('mapearJogosApi').call();
      final mapeados = result.data['mapeados'];
      final pendentes = (result.data['pendentes'] as List?) ?? [];
      if (mounted) {
        mostrarMensagem(
          context,
          pendentes.isEmpty
              ? '$mapeados jogos mapeados com a API.'
              : '$mapeados jogos mapeados. Pendentes (mapeados depois, '
                  'quando os times forem definidos): ${pendentes.join(', ')}.',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) mostrarMensagem(context, e.message ?? 'Erro ao mapear.');
    } catch (e) {
      if (mounted) mostrarMensagem(context, 'Erro: $e');
    } finally {
      if (mounted) setState(() => _mapeandoApi = false);
    }
  }

  Future<void> _recalcularClassica() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Recalcular — Regra Clássica?',
            style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
        content: Text(
          'Todas as pontuações da regra clássica serão recalculadas do zero.',
          style: GoogleFonts.hankenGrotesk(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCELAR',
                style: GoogleFonts.anybody(
                    color: Cores.onSurfaceVariant)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Cores.verdePrincipal),
            child: Text('RECALCULAR',
                style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _recalculando = true);
    try {
      final fn =
          FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      final result = await fn.httpsCallable('recalcularTudo').call();
      final atualizados = result.data['atualizados'];
      if (mounted) {
        mostrarMensagem(
            context, 'Pontuações recalculadas ($atualizados usuários).');
      }
    } catch (e) {
      if (mounted) mostrarMensagem(context, 'Erro ao recalcular: $e');
    } finally {
      if (mounted) setState(() => _recalculando = false);
    }
  }

  Future<void> _recalcularCopa() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Recalcular — Regra Copa?',
            style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
        content: Text(
          'Calcula os pontos da fase de grupos do Modo Copa para todos os usuários e adiciona à pontuação atual.\n\n'
          'Execute APÓS "Recalcular Reg. Clássica". Só pode ser executado uma vez por torneio.',
          style: GoogleFonts.hankenGrotesk(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCELAR',
                style: GoogleFonts.anybody(color: Cores.onSurfaceVariant)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Cores.azulTerciario),
            child: Text('CALCULAR',
                style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _recalculandoCopa = true);
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      final result = await fn.httpsCallable('recalcularCopa').call();
      final atualizados = result.data['atualizados'];
      if (mounted) {
        mostrarMensagem(
            context, 'Pontuação Copa calculada ($atualizados usuários atualizados).');
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'already-exists'
          ? e.message ?? 'Já calculado.'
          : e.code == 'failed-precondition'
              ? e.message ?? 'Pré-condição não atendida.'
              : 'Erro: ${e.message}';
      mostrarMensagem(context, msg);
    } catch (e) {
      if (mounted) mostrarMensagem(context, 'Erro ao calcular: $e');
    } finally {
      if (mounted) setState(() => _recalculandoCopa = false);
    }
  }

  Future<void> _limparDadosTeste() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Limpar dados de teste?',
            style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
        content: Text(
          'Remove todos os placares, restaura os times das eliminatórias para os placeholders, '
          'limpa a classificação, resultados especiais e zera as pontuações de todos os usuários.\n\n'
          'Os palpites dos usuários são preservados.',
          style: GoogleFonts.hankenGrotesk(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCELAR',
                style: GoogleFonts.anybody(color: Cores.onSurfaceVariant)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Cores.error),
            child: Text('LIMPAR TUDO',
                style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _limpandoTeste = true);
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      final result = await fn.httpsCallable('limparDadosTeste').call();
      final jogos = result.data['jogosResetados'];
      final usuarios = result.data['usuariosZerados'];
      if (mounted) {
        mostrarMensagem(
            context, 'Limpeza concluída: $jogos jogos e $usuarios usuários resetados.');
      }
    } catch (e) {
      if (mounted) mostrarMensagem(context, 'Erro: $e');
    } finally {
      if (mounted) setState(() => _limpandoTeste = false);
    }
  }

  Future<void> _adicionarUsuariosGrupoGeral() async {
    final uidsParaAdicionar = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DialogSelecionarUsuariosGeral(),
    );
    if (uidsParaAdicionar == null || uidsParaAdicionar.isEmpty || !mounted) {
      return;
    }

    setState(() => _adicionandoAoGrupo = true);
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      final result = await fn.httpsCallable('adicionarTodosAoGrupo').call({
        'codigo': '0TZGSG',
        'uids': uidsParaAdicionar,
      });
      final adicionados = result.data['adicionados'];
      if (mounted) {
        mostrarMensagem(
            context, '$adicionados usuário(s) adicionado(s) ao grupo GERAL.');
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) mostrarMensagem(context, e.message ?? 'Erro ao adicionar.');
    } catch (e) {
      if (mounted) mostrarMensagem(context, 'Erro: $e');
    } finally {
      if (mounted) setState(() => _adicionandoAoGrupo = false);
    }
  }

  Future<void> _limparOrfaos() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Limpar dados órfãos?',
            style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
        content: Text(
          'Remove documentos de usuários e palpites de contas que foram deletadas '
          'do Firebase Auth. Também tira essas contas dos grupos: grupos que '
          'ficarem vazios são deletados.',
          style: GoogleFonts.hankenGrotesk(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCELAR',
                style: GoogleFonts.anybody(
                    color: Cores.onSurfaceVariant)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Cores.verdePrincipal),
            child: Text('LIMPAR',
                style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _limpando = true);
    try {
      final fn =
          FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      final result =
          await fn.httpsCallable('limparUsuariosOrfaos').call();
      final usuarios = result.data['usuariosRemovidos'];
      final palpites = result.data['palpitesRemovidos'];
      final palpitesCopa = result.data['palpitesCopaRemovidos'] ?? 0;
      final gruposAtualizados = result.data['gruposAtualizados'] ?? 0;
      final gruposRemovidos = result.data['gruposRemovidos'] ?? 0;
      if (mounted) {
        mostrarMensagem(
          context,
          'Limpeza concluída: $usuarios usuário(s), $palpites palpite(s), '
          '$palpitesCopa palpite(s) Copa, '
          '$gruposAtualizados grupo(s) corrigido(s) e '
          '$gruposRemovidos grupo(s) removido(s).',
        );
      }
    } catch (e) {
      if (mounted) mostrarMensagem(context, 'Erro: $e');
    } finally {
      if (mounted) setState(() => _limpando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.background,
      appBar: AppBar(
        backgroundColor: Cores.verdePrincipal,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'OUTRAS DEFINIÇÕES',
          style: GoogleFonts.anybody(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _CardTravar(
            travado: _palpitesTravados ?? false,
            carregando: _travando || _palpitesTravados == null,
            onTap: _alternarTravamento,
          ),
          const SizedBox(height: 12),
          _CardOpcao(
            icone: Icons.cloud_upload_outlined,
            corIcone: Cores.azulTerciario,
            titulo: 'Popular Jogos',
            descricao:
                'Grava os 104 jogos no Firestore (sobrescreve os dados atuais).',
            carregando: _populando,
            onTap: _popularJogos,
          ),
          const SizedBox(height: 12),
          _CardOpcao(
            icone: Icons.link_rounded,
            corIcone: Cores.azulTerciario,
            titulo: 'Mapear Jogos com a API',
            descricao:
                'Grava o id da football-data.org em cada jogo (de-para da '
                'sincronização automática). Rodar após "Popular Jogos".',
            carregando: _mapeandoApi,
            onTap: _mapearJogosApi,
          ),
          const SizedBox(height: 12),
          _CardOpcao(
            icone: Icons.receipt_long_rounded,
            corIcone: Cores.azulTerciario,
            titulo: 'Ver Logs',
            descricao:
                'Histórico das execuções da sincronização com a API '
                '(últimos 7 dias).',
            carregando: false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TelaAdminLogs()),
            ),
          ),
          const SizedBox(height: 12),
          _CardOpcao(
            icone: Icons.sync_rounded,
            corIcone: Cores.verdePrincipal,
            titulo: 'Recalcular — Regra Clássica',
            descricao:
                'Recalcula pontuação de todos os usuários do zero com base nos placares inseridos.',
            carregando: _recalculando,
            onTap: _recalcularClassica,
          ),
          const SizedBox(height: 12),
          _CardOpcao(
            icone: Icons.emoji_events_outlined,
            corIcone: const Color(0xFFFCD400),
            titulo: 'Recalcular — Regra Copa',
            descricao:
                'Calcula os pontos da fase de grupos do Modo Copa para todos os usuários. Executar após inserir todos os placares da fase de grupos.',
            carregando: _recalculandoCopa,
            onTap: _recalcularCopa,
          ),
          const SizedBox(height: 12),
          _CardOpcao(
            icone: Icons.group_add_rounded,
            corIcone: Cores.verdePrincipal,
            titulo: 'Adicionar Usuários ao Grupo GERAL',
            descricao:
                'Seleciona quais usuários adicionar ao grupo GERAL (código 0TZGSG).',
            carregando: _adicionandoAoGrupo,
            onTap: _adicionarUsuariosGrupoGeral,
          ),
          const SizedBox(height: 12),
          _CardOpcao(
            icone: Icons.cleaning_services_rounded,
            corIcone: Cores.error,
            titulo: 'Limpar Dados de Teste',
            descricao:
                'Reseta placares, times eliminatórias, classificação e pontuações. Palpites são preservados.',
            carregando: _limpandoTeste,
            onTap: _limparDadosTeste,
          ),
          const SizedBox(height: 12),
          _CardOpcao(
            icone: Icons.delete_sweep_rounded,
            corIcone: Cores.error,
            titulo: 'Limpar Dados Órfãos',
            descricao:
                'Remove usuários e palpites de contas deletadas do Firebase Auth '
                'e tira essas contas dos grupos (grupos vazios são deletados).',
            carregando: _limpando,
            onTap: _limparOrfaos,
          ),
        ],
      ),
    );
  }
}

// ─── Model auxiliar ──────────────────────────────────────────────────────────

class _UsuarioItem {
  final String uid;
  final String nome;
  final String? avatar;
  final bool jaMembro;
  bool selecionado = false;

  _UsuarioItem({
    required this.uid,
    required this.nome,
    this.avatar,
    required this.jaMembro,
  });
}

// ─── Dialog de seleção de usuários ───────────────────────────────────────────

class _DialogSelecionarUsuariosGeral extends StatefulWidget {
  const _DialogSelecionarUsuariosGeral();

  @override
  State<_DialogSelecionarUsuariosGeral> createState() =>
      _DialogSelecionarUsuariosGeralState();
}

class _DialogSelecionarUsuariosGeralState
    extends State<_DialogSelecionarUsuariosGeral> {
  bool _carregando = true;
  String? _erro;
  List<_UsuarioItem> _usuarios = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('grupos')
            .where('codigo', isEqualTo: '0TZGSG')
            .limit(1)
            .get(),
        FirebaseFirestore.instance.collection('usuarios').get(),
      ]);

      final gruposSnap = results[0];
      final usuariosSnap = results[1];

      final membros = gruposSnap.docs.isNotEmpty
          ? Set<String>.from(
              (gruposSnap.docs.first.data()['membros'] as List? ?? []))
          : <String>{};

      final lista = usuariosSnap.docs.map((doc) {
        final data = doc.data();
        return _UsuarioItem(
          uid: doc.id,
          nome: (data['nome'] as String?) ?? doc.id,
          avatar: data['avatar'] as String?,
          jaMembro: membros.contains(doc.id),
        );
      }).toList()
        ..sort((a, b) {
          // não-membros primeiro; dentro de cada grupo, ordem alfabética
          if (a.jaMembro != b.jaMembro) return a.jaMembro ? 1 : -1;
          return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
        });

      if (mounted) {
        setState(() {
          _usuarios = lista;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _erro = e.toString(); _carregando = false; });
    }
  }

  List<String> get _selecionados =>
      _usuarios.where((u) => u.selecionado).map((u) => u.uid).toList();

  void _toggleTodos() {
    final naoMembros = _usuarios.where((u) => !u.jaMembro).toList();
    final todosSelected = naoMembros.every((u) => u.selecionado);
    setState(() {
      for (final u in naoMembros) {
        u.selecionado = !todosSelected;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selecionadosCount = _selecionados.length;
    final naoMembros = _usuarios.where((u) => !u.jaMembro).toList();
    final todosSelected =
        naoMembros.isNotEmpty && naoMembros.every((u) => u.selecionado);

    return Dialog(
      backgroundColor: Cores.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cabeçalho
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text(
              'Adicionar ao Grupo GERAL',
              style: GoogleFonts.anybody(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Cores.onSurface,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Selecione quem deseja adicionar ao grupo.',
              style: GoogleFonts.hankenGrotesk(
                  fontSize: 13, color: Cores.onSurfaceVariant),
            ),
          ),
          const Divider(height: 1),

          // Botão "Selecionar todos" — só visível quando há não-membros
          if (!_carregando && _erro == null && naoMembros.isNotEmpty)
            InkWell(
              onTap: _toggleTodos,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Checkbox(
                      value: todosSelected,
                      tristate: true,
                      onChanged: (_) => _toggleTodos(),
                      activeColor: Cores.verdePrincipal,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      todosSelected
                          ? 'Desmarcar todos'
                          : 'Selecionar todos',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Cores.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (!_carregando && _erro == null && naoMembros.isNotEmpty)
            const Divider(height: 1),

          // Lista
          Flexible(
            child: _carregando
                ? const Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  )
                : _erro != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Erro ao carregar: $_erro',
                            style: GoogleFonts.hankenGrotesk()),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        itemCount: _usuarios.length,
                        itemBuilder: (_, i) => _buildTile(_usuarios[i]),
                      ),
          ),

          const Divider(height: 1),

          // Ações
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text('CANCELAR',
                      style: GoogleFonts.anybody(
                          color: Cores.onSurfaceVariant)),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: selecionadosCount == 0
                      ? null
                      : () => Navigator.of(context).pop(_selecionados),
                  style: FilledButton.styleFrom(
                      backgroundColor: Cores.verdePrincipal),
                  child: Text(
                    selecionadosCount > 0
                        ? 'ADICIONAR ($selecionadosCount)'
                        : 'ADICIONAR',
                    style:
                        GoogleFonts.anybody(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(_UsuarioItem u) {
    if (u.jaMembro) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Cores.verdePrincipal.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          dense: true,
          leading: WidgetAvatar(
              avatarId: u.avatar, nome: u.nome, tamanho: 34),
          title: Text(u.nome,
              style: GoogleFonts.hankenGrotesk(
                  color: Cores.onSurfaceVariant, fontSize: 14)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Já membro',
                  style: GoogleFonts.hankenGrotesk(
                      fontSize: 11, color: Cores.verdePrincipal)),
              const SizedBox(width: 4),
              const Icon(Icons.check_circle_rounded,
                  color: Cores.verdePrincipal, size: 18),
            ],
          ),
        ),
      );
    }

    final sel = u.selecionado;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: sel
            ? Cores.verdePrincipal.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: sel
            ? Border.all(
                color: Cores.verdePrincipal.withValues(alpha: 0.35),
                width: 1.2)
            : Border.all(color: Colors.transparent),
      ),
      child: ListTile(
        dense: true,
        onTap: () => setState(() => u.selecionado = !u.selecionado),
        leading: WidgetAvatar(
            avatarId: u.avatar, nome: u.nome, tamanho: 34),
        title: Text(u.nome,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 14,
              fontWeight:
                  sel ? FontWeight.w600 : FontWeight.w400,
              color: Cores.onSurface,
            )),
        trailing: Checkbox(
          value: sel,
          onChanged: (_) =>
              setState(() => u.selecionado = !u.selecionado),
          activeColor: Cores.verdePrincipal,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4)),
        ),
      ),
    );
  }
}

// ─── Card de travamento de palpites ──────────────────────────────────────────

class _CardTravar extends StatelessWidget {
  const _CardTravar({
    required this.travado,
    required this.carregando,
    required this.onTap,
  });

  final bool travado;
  final bool carregando;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cor = travado ? Cores.onSurfaceVariant : Cores.error;
    return Material(
      color: travado
          ? Cores.surfaceContainer
          : Cores.error.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: carregando ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
                color: travado ? Cores.outlineVariant : Cores.error),
            borderRadius: BorderRadius.circular(12),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: carregando
                    ? Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: cor),
                        ),
                      )
                    : Icon(
                        travado
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        color: cor,
                        size: 26,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      travado
                          ? 'Palpites Travados'
                          : 'Travar Palpites',
                      style: GoogleFonts.anybody(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: travado
                            ? Cores.onSurfaceVariant
                            : Cores.error,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      travado
                          ? 'Palpites Especiais e Modo Copa já estão visíveis para todos.'
                          : 'Usar no início do jogo de abertura — torna visíveis os Palpites Especiais e o Modo Copa de todos.',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        color: Cores.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: Cores.outlineVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Card-botão de opção ──────────────────────────────────────────────────────

class _CardOpcao extends StatelessWidget {
  const _CardOpcao({
    required this.icone,
    required this.corIcone,
    required this.titulo,
    required this.descricao,
    required this.carregando,
    required this.onTap,
  });

  final IconData icone;
  final Color corIcone;
  final String titulo;
  final String descricao;
  final bool carregando;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Cores.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: carregando ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Cores.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Ícone / loading
              SizedBox(
                width: 40,
                height: 40,
                child: carregando
                    ? Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: corIcone,
                          ),
                        ),
                      )
                    : Icon(icone, color: corIcone, size: 26),
              ),
              const SizedBox(width: 14),
              // Texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: GoogleFonts.anybody(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Cores.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      descricao,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        color: Cores.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: Cores.outlineVariant),
            ],
          ),
        ),
      ),
    );
  }
}


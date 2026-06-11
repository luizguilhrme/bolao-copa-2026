import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grupo.dart';
import '../models/jogo.dart';
import '../models/palpite.dart';
import '../models/usuario.dart';
import '../services/grupo_service.dart';
import '../services/jogo_service.dart';
import '../services/palpite_copa_service.dart';
import '../services/palpite_service.dart';
import '../services/usuario_service.dart';
import '../utils/biblioteca.dart';
import '../utils/cores.dart';
import '../utils/dialogos.dart';

// Cards brancos com sombra suave sobre Cores.background.
const _sombraCard = [
  BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
];

// Ordem canônica das rodadas/fases para o filtro "Por rodada".
const _ordemRodadas = [
  'Rodada 1',
  'Rodada 2',
  'Rodada 3',
  '16 avos de Final',
  'Oitavas de Final',
  'Quartas de Final',
  'Semifinal',
  'Disputa de 3º Lugar',
  'Final',
];

// ─── Modelo interno ───────────────────────────────────────────────────────────

class _ItemResultado {
  const _ItemResultado({
    required this.jogo,
    this.palpite,
    this.pontos,
    this.pontosBase,
  });
  final Jogo jogo;
  final Palpite? palpite;
  final int? pontos; // pontos reais exibidos (com multiplicador de fase)
  final int? pontosBase; // pontos base sem multiplicador — define a cor do card
}

enum _Status { prestesAComecar, aoVivo, encerrado }

// ─── Funções auxiliares (top-level) ──────────────────────────────────────────

_Status _statusDe(Jogo jogo) {
  if (jogo.placar1 != null) return _Status.encerrado;
  return DateTime.now().isAfter(jogo.dataHora.toLocal())
      ? _Status.aoVivo
      : _Status.prestesAComecar;
}

bool _estaBloqueado(Jogo jogo) => DateTime.now().isAfter(
  jogo.dataHora.toLocal().subtract(const Duration(minutes: 5)),
);

// ─── Tela principal ───────────────────────────────────────────────────────────

class TelaPalpites extends StatefulWidget {
  const TelaPalpites({super.key, this.sinalAtualizar});

  /// Disparado pelo MenuPrincipal quando a tela precisa ressincronizar
  /// (aba selecionada ou retorno de rota do drawer).
  final Sinal? sinalAtualizar;

  @override
  State<TelaPalpites> createState() => _TelaPalpitesState();
}

class _TelaPalpitesState extends State<TelaPalpites> {
  bool _abaProximos = true;
  bool _carregando = true;

  // Dados brutos — carregados uma vez do Firestore
  List<Jogo> _todosJogos = [];
  Map<int, Palpite> _palpitesMap = {};
  List<Grupo> _meusGrupos = [];
  Map<String, Map<String, String?>> _palpitesCopa = {};
  Map<String, Map<String, String?>> _classificacaoReal = {};
  bool _palpitesTravados = false;

  // Dados derivados — atualizados pelo timer
  Map<String, List<Jogo>> _gruposProximos = {};
  int _datasVisiveis = 1;
  List<_ItemResultado> _resultados = [];

  // Modo ativo: 'classico' ou 'copa' (só relevante quando ambos os modos presentes)
  bool _modoClassico = true;

  // Filtro de jogos do MODO CLÁSSICO: 0 = Por data | 1 = Por rodada | 2 = Por grupo
  int _filtroJogos = 0;
  String? _rodadaSelecionada;
  String? _grupoSelecionado;

  // Rascunhos digitados mas ainda não salvos — vivem no pai para sobreviver
  // à troca de abas/modo (chave = jogoId)
  final Map<int, ({String p1, String p2})> _rascunhos = {};
  Map<String, Map<String, String?>>? _copaRascunho;

  DateTime? _criadoEm;
  Timer? _timer;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _carregar();
    widget.sinalAtualizar?.addListener(_recarregarSilencioso);
    // Reclassifica a cada 30s para mover jogos entre abas automaticamente
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _reclassificar(preservarDatasVisiveis: true);
    });
  }

  @override
  void dispose() {
    widget.sinalAtualizar?.removeListener(_recarregarSilencioso);
    _timer?.cancel();
    super.dispose();
  }

  // Ressincroniza os dados sem spinner de tela cheia: scroll, sub-aba ativa
  // e rascunhos digitados são preservados. Cobre o caso de entrar/criar grupo
  // de outro modo em Meus Grupos e voltar para cá.
  void _recarregarSilencioso() => _carregar(silencioso: true);

  Future<void> _carregar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _carregando = true);
    try {
      // Carrega dados essenciais em paralelo
      final results = await Future.wait([
        JogoService().buscarTodos(),
        PalpiteService().buscarTodosPorUsuario(_uid),
        UsuarioService().buscarPorUid(_uid),
        GrupoService().buscarGruposDoUsuarioOnce(_uid),
      ]);
      _todosJogos = results[0] as List<Jogo>;
      final palpites = results[1] as List<Palpite>;
      _criadoEm = (results[2] as Usuario?)?.criadoEm;
      _meusGrupos = results[3] as List<Grupo>;
      _palpitesMap = {for (final p in palpites) p.jogoId: p};

      // Palpites Copa e classificação real carregados separadamente — um erro
      // aqui não deve derrubar o carregamento dos jogos e palpites clássicos.
      try {
        _palpitesCopa = await PalpiteCopaService().buscarPorUid(_uid);
      } catch (_) {
        _palpitesCopa = {};
      }

      try {
        final doc =
            await FirebaseFirestore.instance
                .collection('config')
                .doc('copa2026')
                .get();
        final data = doc.data();
        final cr = data?['classificacao_real'] as Map<String, dynamic>?;
        if (cr != null) {
          _classificacaoReal = cr.map((k, v) {
            final m = v as Map<String, dynamic>;
            return MapEntry(k, {
              'primeiro': m['primeiro'] as String?,
              'segundo': m['segundo'] as String?,
              'terceiro': m['terceiro'] as String?,
            });
          });
        }
        _palpitesTravados = (data?['palpitesTravados'] as bool?) ?? false;
      } catch (_) {
        _classificacaoReal = {};
      }

      _reclassificar(preservarDatasVisiveis: silencioso);
    } catch (e) {
      // Em recarga silenciosa, mantém os dados antigos em caso de erro
      if (!silencioso) setState(() => _carregando = false);
    }
  }

  void _reclassificar({required bool preservarDatasVisiveis}) {
    final agora = DateTime.now();
    final proximos = <String, List<Jogo>>{};
    final resultados = <_ItemResultado>[];

    for (final jogo in _todosJogos) {
      // Pular jogos cujos times ainda não foram definidos (fase mata-mata)
      if (ehPlaceholder(jogo.team1) || ehPlaceholder(jogo.team2)) continue;

      final cutoff = jogo.dataHora.toLocal().subtract(
        const Duration(minutes: 5),
      );

      if (agora.isBefore(cutoff) && jogo.placar1 == null) {
        // Disponível para palpite
        final local = jogo.dataHora.toLocal();
        final chave =
            '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
        proximos.putIfAbsent(chave, () => []).add(jogo);
      } else {
        // Bloqueado, ao vivo ou encerrado
        resultados.add(_itemResultadoDe(jogo));
      }
    }

    resultados.sort((a, b) => b.jogo.dataHora.compareTo(a.jogo.dataHora));

    final datas = proximos.keys.toList();

    setState(() {
      _gruposProximos = proximos;
      _datasVisiveis =
          preservarDatasVisiveis
              ? _datasVisiveis.clamp(1, datas.isEmpty ? 1 : datas.length)
              : 1;
      _resultados = resultados;
      _carregando = false;
    });
  }

  // Monta o item de resultado (palpite + pontos) de um jogo bloqueado,
  // ao vivo ou encerrado. Usado pela aba Encerrados e pelas listas filtradas.
  _ItemResultado _itemResultadoDe(Jogo jogo) {
    final palpite = _palpitesMap[jogo.id];
    int? pontos;
    int? pontosBase;
    if (jogo.placar1 != null && jogo.placar2 != null) {
      if (palpite != null) {
        pontosBase = calcularPontos(
          palpite.palpite1,
          palpite.palpite2,
          jogo.placar1!,
          jogo.placar2!,
        );
        pontos = calcularPontosComFase(
          palpite.palpite1,
          palpite.palpite2,
          jogo.placar1!,
          jogo.placar2!,
          jogo.round,
        );
      } else if (_criadoEm != null && jogo.dataHora.isAfter(_criadoEm!)) {
        pontos = -10;
        pontosBase = -10;
      }
    }
    return _ItemResultado(
      jogo: jogo,
      palpite: palpite,
      pontos: pontos,
      pontosBase: pontosBase,
    );
  }

  // Chamado pelo card quando o usuário salva um palpite novo
  void _onPalpiteSalvo(Palpite palpite) {
    _palpitesMap[palpite.jogoId] = palpite;
  }

  // Salva palpites do MODO COPA e atualiza estado local
  Future<void> _salvarPalpitesCopa(
    Map<String, Map<String, String?>> palpites,
  ) async {
    await PalpiteCopaService().salvar(_uid, palpites);
    if (mounted) setState(() => _palpitesCopa = palpites);
  }

  // ─── Computed properties ────────────────────────────────────────────────────

  /// True se os 16 avos de final já têm times definidos (Fase de Grupos encerrada).
  bool get _faseGruposEncerrada {
    final j73 = _todosJogos.where((j) => j.id == 73).firstOrNull;
    return j73 != null && !ehPlaceholder(j73.team1);
  }

  bool get _temModoClassico =>
      _meusGrupos.isEmpty || _meusGrupos.any((g) => g.regra == 'classico');

  bool get _temModoCopa => _meusGrupos.any((g) => g.regra == 'copa');

  /// True se o usuário tem ambos os modos E a Fase de Grupos ainda está ativa
  /// OU a classificação real já foi divulgada (para exibir resultados Copa).
  bool get _mostrarAbas =>
      _temModoClassico &&
      _temModoCopa &&
      (!_faseGruposEncerrada || _classificacaoReal.isNotEmpty);

  /// Palpites Copa bloqueados apenas quando admin trava.
  bool get _copaBloqueada => _palpitesTravados;

  /// Times de cada grupo extraídos dos jogos da Fase de Grupos.
  Map<String, List<String>> get _timesPorGrupo {
    final mapa = <String, Set<String>>{};
    for (final jogo in _todosJogos) {
      if (jogo.group == null) continue;
      final letra = jogo.group!.replaceAll('Grupo ', '');
      mapa.putIfAbsent(letra, () => <String>{})
        ..add(jogo.team1)
        ..add(jogo.team2);
    }
    const ordem = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L'];
    return {
      for (final k in ordem)
        if (mapa.containsKey(k)) k: mapa[k]!.toList(),
    };
  }

  // Próximos filtrados por fase (Fase de Grupos ou Knockout)
  Map<String, List<Jogo>> get _proximosFiltrados {
    final result = <String, List<Jogo>>{};
    for (final entry in _gruposProximos.entries) {
      final filtrado =
          _faseGruposEncerrada
              ? entry.value.where((j) => j.group == null).toList()
              : entry.value.where((j) => j.group != null).toList();
      if (filtrado.isNotEmpty) result[entry.key] = filtrado;
    }
    return result;
  }

  // Encerrados filtrados por fase
  List<_ItemResultado> get _encerradosFiltrados =>
      _faseGruposEncerrada
          ? _resultados
          : _resultados.where((r) => r.jogo.group != null).toList();

  bool get _temMaisProximos =>
      !_faseGruposEncerrada && _datasVisiveis < _proximosFiltrados.length;

  List<String> get _datasAtivas {
    final datas = _proximosFiltrados.keys.toList();
    if (_faseGruposEncerrada) return datas;
    return datas.take(_datasVisiveis).toList();
  }

  /// Rodadas/fases presentes nos jogos, na ordem canônica do torneio.
  List<String> get _opcoesRodada {
    final presentes = _todosJogos.map((j) => j.matchday ?? j.round).toSet();
    return [
      for (final r in _ordemRodadas)
        if (presentes.contains(r)) r,
    ];
  }

  List<String> get _opcoesGrupo =>
      _todosJogos.map((j) => j.group).whereType<String>().toSet().toList()
        ..sort();

  Future<void> _abrirSeletorFiltro() async {
    final porRodada = _filtroJogos == 1;
    final escolha = await mostrarSeletorOpcoes(
      context,
      titulo: porRodada ? 'Rodada / Fase' : 'Grupo',
      opcoes: porRodada ? _opcoesRodada : _opcoesGrupo,
      selecionada: porRodada ? _rodadaSelecionada : _grupoSelecionado,
    );
    if (escolha == null || !mounted) return;
    setState(() {
      if (porRodada) {
        _rodadaSelecionada = escolha;
      } else {
        _grupoSelecionado = escolha;
      }
    });
  }

  /// Lista mista (cards de palpite editáveis + cards de resultado) usada
  /// pelos filtros "Por rodada" e "Por grupo", agrupada por data.
  Widget _buildListaFiltrada() {
    final porRodada = _filtroJogos == 1;
    final selecao = porRodada ? _rodadaSelecionada : _grupoSelecionado;

    final jogos =
        _todosJogos.where((j) {
            if (ehPlaceholder(j.team1) || ehPlaceholder(j.team2)) return false;
            return porRodada
                ? (j.matchday ?? j.round) == selecao
                : j.group == selecao;
          }).toList()
          ..sort((a, b) => a.dataHora.compareTo(b.dataHora));

    if (jogos.isEmpty) {
      return Center(
        child: Text(
          'Nenhum jogo disponível para esta seleção.',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 14,
            color: Cores.onSurfaceVariant,
          ),
        ),
      );
    }

    final agora = DateTime.now();
    final filhos = <Widget>[];
    String? dataAtual;
    for (final jogo in jogos) {
      final local = jogo.dataHora.toLocal();
      final chave =
          '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
      if (chave != dataAtual) {
        dataAtual = chave;
        filhos.add(
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _CabecalhoData(dataChave: chave),
          ),
        );
      }

      final cutoff = jogo.dataHora.toLocal().subtract(
        const Duration(minutes: 5),
      );
      final disponivel = jogo.placar1 == null && agora.isBefore(cutoff);
      filhos.add(
        disponivel
            // Card editável: o pill de horário flutua acima (top: -12),
            // então precisa de respiro extra no topo
            ? Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: _CardPalpite(
                key: ValueKey(jogo.id),
                jogo: jogo,
                palpiteInicial: _palpitesMap[jogo.id],
                rascunhos: _rascunhos,
                onPalpiteSalvo: _onPalpiteSalvo,
              ),
            )
            : Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: _CardResultado(item: _itemResultadoDe(jogo)),
            ),
      );
    }

    return ListView(
      key: ValueKey('filtro-$_filtroJogos-$selecao'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: filhos,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    // Determina se o conteúdo atual é Copa (bet form/results) ou Clássico (jogos)
    final bool exibirCopa =
        (!_faseGruposEncerrada || _classificacaoReal.isNotEmpty) &&
        ((_mostrarAbas && !_modoClassico) ||
            (_temModoCopa && !_temModoClassico));

    final int countProximos =
        exibirCopa
            ? 0
            : _proximosFiltrados.values.fold(0, (s, l) => s + l.length);
    final int countEncerrados = exibirCopa ? 0 : _encerradosFiltrados.length;

    return Container(
      color: Cores.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner informativo quando palpites Copa e Especiais estão travados
          if (_palpitesTravados)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Cores.verdePrincipal.withValues(alpha: 0.10),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    size: 16,
                    color: Cores.verdePrincipal,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Palpites Especiais e Modo Copa estão travados e visíveis para todos.',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13,
                        color: Cores.verdePrincipal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Seletor de MODO (só quando ambos os modos presentes e fase de grupos ativa)
          if (_mostrarAbas)
            _SeletorModo(
              modoClassico: _modoClassico,
              onChanged:
                  (v) => setState(() {
                    _modoClassico = v;
                    _abaProximos = true; // reset sub-aba ao trocar de modo
                  }),
            ),

          // Copa: sub-abas direto. Clássico: título + chips de filtro
          // (Por data / Por rodada / Por grupo) e o controle correspondente.
          if (exibirCopa)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _SeletorAbas(
                abaProximos: _abaProximos,
                countProximos: 0,
                countEncerrados: 0,
                modoCopa: true,
                onChanged: (v) => setState(() => _abaProximos = v),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _ChipsFiltroJogos(
                filtro: _filtroJogos,
                onChanged:
                    (f) => setState(() {
                      _filtroJogos = f;
                      // Pré-seleciona a primeira opção ao entrar no filtro
                      if (f == 1 && _rodadaSelecionada == null) {
                        final ops = _opcoesRodada;
                        if (ops.isNotEmpty) _rodadaSelecionada = ops.first;
                      }
                      if (f == 2 && _grupoSelecionado == null) {
                        final ops = _opcoesGrupo;
                        if (ops.isNotEmpty) _grupoSelecionado = ops.first;
                      }
                    }),
              ),
            ),
            if (_filtroJogos == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _SeletorAbas(
                  abaProximos: _abaProximos,
                  countProximos: countProximos,
                  countEncerrados: countEncerrados,
                  onChanged: (v) => setState(() => _abaProximos = v),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _CampoSeletorFiltro(
                  valor:
                      _filtroJogos == 1
                          ? _rodadaSelecionada
                          : _grupoSelecionado,
                  onTap: _abrirSeletorFiltro,
                ),
              ),
          ],

          // Conteúdo principal
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child:
                  exibirCopa
                      ? (_abaProximos
                          ? _AbaCopaProximos(
                            key: const ValueKey('copa-proximos'),
                            timesPorGrupo: _timesPorGrupo,
                            palpites: _palpitesCopa,
                            rascunho: _copaRascunho,
                            onRascunho: (m) => _copaRascunho = m,
                            bloqueado: _copaBloqueada,
                            onSalvar: _salvarPalpitesCopa,
                          )
                          : _AbaCopaEncerrados(
                            key: const ValueKey('copa-encerrados'),
                            palpites: _palpitesCopa,
                            classificacaoReal: _classificacaoReal,
                          ))
                      : _filtroJogos != 0
                      ? _buildListaFiltrada()
                      : (_abaProximos
                          ? _AbaProximos(
                            key: const ValueKey('proximos'),
                            grupos: _proximosFiltrados,
                            datasAtivas: _datasAtivas,
                            palpitesMap: _palpitesMap,
                            rascunhos: _rascunhos,
                            temMais: _temMaisProximos,
                            onVerMais: () => setState(() => _datasVisiveis++),
                            onPalpiteSalvo: _onPalpiteSalvo,
                          )
                          : _AbaEncerrados(
                            key: const ValueKey('encerrados'),
                            resultados: _encerradosFiltrados,
                          )),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Seletor de abas ──────────────────────────────────────────────────────────

class _SeletorAbas extends StatelessWidget {
  const _SeletorAbas({
    required this.abaProximos,
    required this.countProximos,
    required this.countEncerrados,
    required this.onChanged,
    this.modoCopa = false,
  });

  final bool abaProximos;
  final int countProximos;
  final int countEncerrados;
  final void Function(bool) onChanged;

  /// No MODO COPA Próximos não há lista de jogos — esconde o contador
  final bool modoCopa;

  @override
  Widget build(BuildContext context) {
    // Card único segmentado (mesmo aspecto do campo seletor de rodada/grupo):
    // seleção em branco suave, sem verde — a tela já tem verde nas abas e chips.
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Cores.verdeSuave,
        border: Border.all(color: Cores.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentoAba(
              label: 'Próximos',
              count: modoCopa ? 0 : countProximos,
              ativo: abaProximos,
              onTap: () => onChanged(true),
            ),
          ),
          // Divisão central do card
          Container(
            width: 1,
            height: 20,
            color: Cores.outlineVariant,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          Expanded(
            child: _SegmentoAba(
              label: 'Encerrados',
              count: modoCopa ? 0 : countEncerrados,
              ativo: !abaProximos,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentoAba extends StatelessWidget {
  const _SegmentoAba({
    required this.label,
    required this.count,
    required this.ativo,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool ativo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: ativo ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow:
              ativo
                  ? const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.anybody(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ativo ? Cores.onSurface : Cores.onSurfaceVariant,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ativo ? Cores.verdeSuave : Cores.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Cores.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Chips de filtro de jogos (Por data / Por rodada / Por grupo) ─────────────

class _ChipsFiltroJogos extends StatelessWidget {
  const _ChipsFiltroJogos({required this.filtro, required this.onChanged});

  final int filtro;
  final void Function(int) onChanged;

  static const _labels = ['Por data', 'Por rodada', 'Por grupo'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _buildChip(_labels[i], i),
        ],
      ],
    );
  }

  Widget _buildChip(String label, int indice) {
    final selecionado = filtro == indice;
    return GestureDetector(
      onTap: () => onChanged(indice),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selecionado ? Cores.verdePrincipal : Cores.verdeSuave,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selecionado ? Cores.verdePrincipal : Cores.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.anybody(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selecionado ? Colors.white : Cores.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ─── Campo seletor de rodada/grupo (abre bottom sheet de opções) ──────────────

class _CampoSeletorFiltro extends StatelessWidget {
  const _CampoSeletorFiltro({required this.valor, required this.onTap});

  final String? valor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Cores.surfaceContainer,
          border: Border.all(color: Cores.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.filter_list_rounded,
              size: 20,
              color: Cores.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                valor ?? 'Selecionar...',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 15,
                  fontWeight: valor != null ? FontWeight.w600 : FontWeight.w400,
                  color:
                      valor != null ? Cores.onSurface : Cores.onSurfaceVariant,
                ),
              ),
            ),
            const Icon(
              Icons.expand_more_rounded,
              color: Cores.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Aba Próximos ─────────────────────────────────────────────────────────────

class _AbaProximos extends StatefulWidget {
  const _AbaProximos({
    super.key,
    required this.grupos,
    required this.datasAtivas,
    required this.palpitesMap,
    required this.rascunhos,
    required this.temMais,
    required this.onVerMais,
    required this.onPalpiteSalvo,
  });

  final Map<String, List<Jogo>> grupos;
  final List<String> datasAtivas;
  final Map<int, Palpite> palpitesMap;
  final Map<int, ({String p1, String p2})> rascunhos;
  final bool temMais;
  final VoidCallback onVerMais;
  final void Function(Palpite) onPalpiteSalvo;

  @override
  State<_AbaProximos> createState() => _AbaProximosState();
}

class _AbaProximosState extends State<_AbaProximos> {
  final List<FocusNode> _focusNodes = [];

  int get _totalCards => widget.datasAtivas.fold<int>(
    0,
    (s, d) => s + (widget.grupos[d]?.length ?? 0),
  );

  @override
  void initState() {
    super.initState();
    _reconstruirFocusNodes(_totalCards);
  }

  @override
  void didUpdateWidget(_AbaProximos old) {
    super.didUpdateWidget(old);
    final total = _totalCards;
    if (total != _focusNodes.length) _reconstruirFocusNodes(total);
  }

  void _reconstruirFocusNodes(int count) {
    for (final fn in _focusNodes) {
      fn.dispose();
    }
    _focusNodes
      ..clear()
      ..addAll(List.generate(count, (_) => FocusNode()));
  }

  @override
  void dispose() {
    for (final fn in _focusNodes) {
      fn.dispose();
    }
    super.dispose();
  }

  void _onSalvoComEnter(int index) {
    final next = index + 1;
    if (next < _focusNodes.length) {
      _focusNodes[next].requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.grupos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sports_soccer_rounded,
              size: 64,
              color: Cores.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum jogo disponível',
              style: GoogleFonts.anybody(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Cores.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Todos os jogos já foram encerrados\nou estão prestes a começar.',
              textAlign: TextAlign.center,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 14,
                color: Cores.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    final slivers = <Widget>[];

    int cardIndex = 0;
    for (final chave in widget.datasAtivas) {
      final jogos = widget.grupos[chave]!;
      final baseIndex = cardIndex;

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          sliver: SliverToBoxAdapter(child: _CabecalhoData(dataChave: chave)),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((_, i) {
              final idx = baseIndex + i;
              return Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 4),
                child: _CardPalpite(
                  key: ValueKey(jogos[i].id),
                  jogo: jogos[i],
                  palpiteInicial: widget.palpitesMap[jogos[i].id],
                  rascunhos: widget.rascunhos,
                  onPalpiteSalvo: widget.onPalpiteSalvo,
                  focusCtrl1:
                      idx < _focusNodes.length ? _focusNodes[idx] : null,
                  onSalvoComEnter: () => _onSalvoComEnter(idx),
                ),
              );
            }, childCount: jogos.length),
          ),
        ),
      );
      cardIndex += jogos.length;
    }

    slivers.add(
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        sliver: SliverToBoxAdapter(
          child:
              widget.temMais
                  ? _BotaoVerMais(onTap: widget.onVerMais)
                  : const _FimDaLista(),
        ),
      ),
    );

    return CustomScrollView(slivers: slivers);
  }
}

// ─── Aba Encerrados ───────────────────────────────────────────────────────────

class _AbaEncerrados extends StatelessWidget {
  const _AbaEncerrados({super.key, required this.resultados});

  final List<_ItemResultado> resultados;

  @override
  Widget build(BuildContext context) {
    if (resultados.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              size: 64,
              color: Cores.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum resultado ainda',
              style: GoogleFonts.anybody(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Cores.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Os jogos aparecerão aqui\nquando estiverem prestes a começar.',
              textAlign: TextAlign.center,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 14,
                color: Cores.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      itemCount: resultados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _CardResultado(item: resultados[i]),
    );
  }
}

// ─── Card de palpite (aba Próximos) ──────────────────────────────────────────

class _CardPalpite extends StatefulWidget {
  const _CardPalpite({
    super.key,
    required this.jogo,
    required this.palpiteInicial,
    required this.rascunhos,
    required this.onPalpiteSalvo,
    this.focusCtrl1,
    this.onSalvoComEnter,
  });

  final Jogo jogo;
  final Palpite? palpiteInicial;
  final Map<int, ({String p1, String p2})> rascunhos;
  final void Function(Palpite) onPalpiteSalvo;
  final FocusNode? focusCtrl1;
  final VoidCallback? onSalvoComEnter;

  @override
  State<_CardPalpite> createState() => _CardPalpiteState();
}

class _CardPalpiteState extends State<_CardPalpite> {
  late final TextEditingController _ctrl1;
  late final TextEditingController _ctrl2;
  final _focusCtrl2 = FocusNode();
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  Palpite? _ultimoSalvo; // último palpite persistido no Firestore
  bool _salvando = false;
  Timer? _debounce;
  String _txtAnterior1 = '';
  String _txtAnterior2 = '';

  /// True quando os campos refletem exatamente o palpite salvo.
  bool get _salvo {
    final p = _ultimoSalvo;
    return p != null &&
        _ctrl1.text == '${p.palpite1}' &&
        _ctrl2.text == '${p.palpite2}';
  }

  /// True quando há texto digitado que ainda não foi persistido.
  bool get _pendente =>
      !_salvo && (_ctrl1.text.isNotEmpty || _ctrl2.text.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _ultimoSalvo = widget.palpiteInicial;
    // Restaura rascunho não salvo (sobrevive à troca de aba/modo);
    // senão pré-preenche com o palpite precarregado pelo pai
    final r = widget.rascunhos[widget.jogo.id];
    final p = widget.palpiteInicial;
    _ctrl1 = TextEditingController(
      text: r?.p1 ?? (p != null ? '${p.palpite1}' : ''),
    );
    _ctrl2 = TextEditingController(
      text: r?.p2 ?? (p != null ? '${p.palpite2}' : ''),
    );
    _txtAnterior1 = _ctrl1.text;
    _txtAnterior2 = _ctrl2.text;
    _ctrl1.addListener(_onTextoAlterado);
    _ctrl2.addListener(_onTextoAlterado);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _salvarPendenteAoSair();
    _ctrl1.dispose();
    _ctrl2.dispose();
    _focusCtrl2.dispose();
    super.dispose();
  }

  // Última chance: card sendo destruído (troca de aba/modo) com palpite
  // completo ainda não salvo — dispara o save sem aguardar o resultado.
  void _salvarPendenteAoSair() {
    if (_salvo || _salvando || _estaBloqueado(widget.jogo)) return;
    final v1 = int.tryParse(_ctrl1.text);
    final v2 = int.tryParse(_ctrl2.text);
    if (v1 == null || v2 == null) return;
    final novo = Palpite(
      uid: _uid,
      jogoId: widget.jogo.id,
      palpite1: v1,
      palpite2: v2,
      criadoEm: DateTime.now(),
    );
    PalpiteService().salvar(novo);
    widget.onPalpiteSalvo(novo);
    widget.rascunhos.remove(widget.jogo.id);
  }

  void _onTextoAlterado() {
    // O controller também notifica mudanças de seleção/cursor — ignora
    if (_ctrl1.text == _txtAnterior1 && _ctrl2.text == _txtAnterior2) return;
    _txtAnterior1 = _ctrl1.text;
    _txtAnterior2 = _ctrl2.text;

    if (_salvo) {
      widget.rascunhos.remove(widget.jogo.id);
    } else {
      widget.rascunhos[widget.jogo.id] = (p1: _ctrl1.text, p2: _ctrl2.text);
    }

    // Auto-save: dispara sozinho 1s após o usuário parar de digitar,
    // quando os dois placares estão preenchidos
    _debounce?.cancel();
    if (!_salvo &&
        int.tryParse(_ctrl1.text) != null &&
        int.tryParse(_ctrl2.text) != null) {
      _debounce = Timer(const Duration(seconds: 1), () => _salvar(auto: true));
    }

    setState(() {}); // atualiza borda/cadeado (estado "não salvo")
  }

  Future<void> _salvar({bool fromEnter = false, bool auto = false}) async {
    if (!mounted || _salvando) return;

    // Trava de segurança: impede salvar após o cutoff de 5 min
    if (_estaBloqueado(widget.jogo)) {
      if (!auto) {
        mostrarMensagem(context, 'Palpites encerrados para este jogo.');
      }
      return;
    }

    final v1 = int.tryParse(_ctrl1.text);
    final v2 = int.tryParse(_ctrl2.text);
    if (v1 == null || v2 == null) {
      if (!auto) {
        mostrarMensagem(context, 'Preencha os dois placares antes de salvar.');
      }
      return;
    }

    // Nada mudou desde o último save — só trata a navegação por Enter
    if (_salvo) {
      if (fromEnter) widget.onSalvoComEnter?.call();
      return;
    }

    _debounce?.cancel();
    setState(() => _salvando = true);

    final novoPalpite = Palpite(
      uid: _uid,
      jogoId: widget.jogo.id,
      palpite1: v1,
      palpite2: v2,
      criadoEm: DateTime.now(),
    );

    try {
      await PalpiteService().salvar(novoPalpite);
    } catch (_) {
      if (!mounted) return;
      setState(() => _salvando = false);
      mostrarMensagem(context, 'Erro ao salvar. Tente novamente.');
      return;
    }

    if (!mounted) return;
    setState(() {
      _ultimoSalvo = novoPalpite;
      _salvando = false;
    });
    widget.rascunhos.remove(widget.jogo.id);
    widget.onPalpiteSalvo(novoPalpite);

    if (fromEnter) {
      widget.onSalvoComEnter?.call();
    } else if (!auto) {
      FocusScope.of(context).unfocus();
    }

    // Confirmação visual do save
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    mostrarSnackBarSucesso(
      context,
      'Palpite salvo: ${nomePtDe(widget.jogo.team1)} $v1 × $v2 '
      '${nomePtDe(widget.jogo.team2)}',
      duration: const Duration(milliseconds: 1600),
    );
  }

  String get _horario {
    final l = widget.jogo.dataHora.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final salvo = _salvo;
    final pendente = _pendente;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            // Branco + sombra; a borda só sinaliza estado: verde = salvo,
            // amarela = digitado e não salvo, sem palpite = sem borda.
            color: Colors.white,
            border: Border.all(
              color:
                  salvo
                      ? Cores.verdePrincipal
                      : pendente
                      ? Cores.secondaryContainer
                      : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _sombraCard,
          ),
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
          // Miolo com largura intrínseca (como no card da tela Teste de API):
          // os lados dividem o espaço restante e bandeira/nome ficam
          // centralizados, sem colar na lateral do card.
          child: Row(
            children: [
              Expanded(child: _Time(nome: widget.jogo.team1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: _InputsProximos(
                  ctrl1: _ctrl1,
                  ctrl2: _ctrl2,
                  focusCtrl1: widget.focusCtrl1,
                  focusCtrl2: _focusCtrl2,
                  onSalvar: () => _salvar(fromEnter: true),
                ),
              ),
              Expanded(child: _Time(nome: widget.jogo.team2)),
            ],
          ),
        ),

        // Pill de horário
        Positioned(
          top: -12,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Cores.surfaceContainer,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Cores.outlineVariant),
              ),
              child: Text(
                _horario,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Cores.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),

        // Status do save: spinner (salvando), cadeado fechado verde (salvo),
        // cadeado aberto amarelo (digitado mas não salvo) ou cinza (vazio).
        // Tocar também salva — redundante com o auto-save, mas mantém o
        // gesto antigo funcionando.
        Positioned(
          top: 8,
          right: 8,
          child:
              _salvando
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Cores.verdePrincipal,
                    ),
                  )
                  : GestureDetector(
                    onTap: salvo ? null : () => _salvar(),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        salvo ? Icons.lock_rounded : Icons.lock_open_rounded,
                        key: ValueKey('$salvo-$pendente'),
                        size: 20,
                        color:
                            salvo
                                ? Cores.verdePrincipal
                                : pendente
                                ? Cores.onSecondaryContainer
                                : Cores.onSurfaceVariant,
                      ),
                    ),
                  ),
        ),
      ],
    );
  }
}

// ─── Card de resultado (aba Resultados) ───────────────────────────────────────

class _CardResultado extends StatelessWidget {
  const _CardResultado({required this.item});

  final _ItemResultado item;

  Jogo get jogo => item.jogo;
  Palpite? get palpite => item.palpite;
  int? get pontos => item.pontos;
  int? get pontosBase => item.pontosBase;

  String get _horario {
    final l = jogo.dataHora.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusDe(jogo);
    final encerrado = status == _Status.encerrado;

    return Container(
      decoration: BoxDecoration(
        // Estilo novo (branco + sombra); cor de fundo/borda de pontuação
        // permanece nos encerrados — é o indicador visual do acerto.
        color: encerrado ? corFundoPontuacao(pontosBase) : Colors.white,
        border: Border.all(
          color:
              encerrado ? corBordaPontuacao(pontosBase) : Cores.outlineVariant,
          width: encerrado && pontosBase != null ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: _sombraCard,
      ),
      child: Column(
        children: [
          // Cabeçalho: grupo/fase + status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Cores.surfaceContainer,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  jogo.group ?? jogo.round,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Cores.onSurfaceVariant,
                  ),
                ),
                _ChipStatus(status: status, horario: _horario),
              ],
            ),
          ),

          // Times + palpite
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _Time(nome: jogo.team1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: _ScoreDisplay(
                        valor1: palpite != null ? '${palpite!.palpite1}' : '—',
                        valor2: palpite != null ? '${palpite!.palpite2}' : '—',
                        label: palpite != null ? 'Seu palpite' : 'Sem palpite',
                        corTexto: Cores.onSurface,
                      ),
                    ),
                    Expanded(child: _Time(nome: jogo.team2)),
                  ],
                ),

                // Resultado real (só se encerrado)
                if (encerrado && jogo.placar1 != null) ...[
                  const SizedBox(height: 8),
                  Divider(
                    color: corBordaPontuacao(pontosBase).withValues(alpha: 0.3),
                    height: 1,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Spacer(),
                      _ScoreDisplay(
                        valor1: '${jogo.placar1}',
                        valor2: '${jogo.placar2}',
                        label: 'Resultado',
                        corTexto: Cores.onSurfaceVariant,
                        compacto: true,
                      ),
                      const Spacer(),
                    ],
                  ),
                  // Indicador de quem avançou nos pênaltis/prorrogação
                  if (jogo.vencedor != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          size: 13,
                          color: Cores.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Avançou: ${nomePtDe(jogo.vencedor!)}',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Cores.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),

          // Rodapé: pontuação + horário do palpite
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Badge de pontos (só se encerrado)
                if (encerrado)
                  _BadgePontos(
                    pontos: pontos,
                    pontosBase: pontosBase,
                    temPalpite: palpite != null,
                  )
                else
                  const SizedBox.shrink(),

                // criadoEm
                if (palpite?.criadoEm != null)
                  Text(
                    'Registrado em ${formatarCriadoEm(palpite!.criadoEm)}',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 11,
                      color: Cores.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _ChipStatus extends StatelessWidget {
  const _ChipStatus({required this.status, required this.horario});

  final _Status status;
  final String horario;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _Status.aoVivo:
        return const _ChipAoVivo();
      case _Status.prestesAComecar:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFCD400).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFFFCD400).withValues(alpha: 0.6),
            ),
          ),
          child: Text(
            'PRESTES A COMEÇAR',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6E5C00),
            ),
          ),
        );
      case _Status.encerrado:
        return Text(
          horario,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Cores.onSurfaceVariant,
          ),
        );
    }
  }
}

class _ChipAoVivo extends StatefulWidget {
  const _ChipAoVivo();

  @override
  State<_ChipAoVivo> createState() => _ChipAoVivoState();
}

class _ChipAoVivoState extends State<_ChipAoVivo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Cores.primaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Cores.primaryContainer),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder:
                (_, __) => Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Cores.verdePrincipal.withValues(
                      alpha: 0.4 + 0.6 * _ctrl.value,
                    ),
                  ),
                ),
          ),
          const SizedBox(width: 4),
          Text(
            'AO VIVO',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Cores.verdePrincipal,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreDisplay extends StatelessWidget {
  const _ScoreDisplay({
    required this.valor1,
    required this.valor2,
    required this.label,
    required this.corTexto,
    this.compacto = false,
  });

  final String valor1;
  final String valor2;
  final String label;
  final Color corTexto;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final fontSize = compacto ? 18.0 : 24.0;
    final boxSize = compacto ? 40.0 : 52.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ScoreBox(valor: valor1, size: boxSize, fontSize: fontSize),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '×',
                style: GoogleFonts.anybody(
                  fontSize: compacto ? 16 : 20,
                  fontWeight: FontWeight.w600,
                  color: Cores.onSurfaceVariant,
                ),
              ),
            ),
            _ScoreBox(valor: valor2, size: boxSize, fontSize: fontSize),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Cores.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({
    required this.valor,
    required this.size,
    required this.fontSize,
  });

  final String valor;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Cores.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Cores.outlineVariant),
      ),
      child: Center(
        child: Text(
          valor,
          style: GoogleFonts.hankenGrotesk(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: Cores.onSurface,
          ),
        ),
      ),
    );
  }
}

class _BadgePontos extends StatelessWidget {
  const _BadgePontos({
    required this.pontos,
    required this.pontosBase,
    required this.temPalpite,
  });

  final int? pontos; // valor exibido (com multiplicador de fase)
  final int? pontosBase; // valor base (define a cor)
  final bool temPalpite;

  @override
  Widget build(BuildContext context) {
    // Punição por não ter palpitado
    if ((pontosBase ?? 0) < 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '−10 pts',
          style: GoogleFonts.anybody(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
    }

    // Jogo encerrado mas sem palpite registrado (e sem punição = cadastro após o jogo)
    if (!temPalpite) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFBBCBB9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Sem palpite',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }

    final pts = pontos ?? 0;
    final base = pontosBase ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: corPontuacao(base),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$pts pts',
        style: GoogleFonts.anybody(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _InputsProximos extends StatelessWidget {
  const _InputsProximos({
    required this.ctrl1,
    required this.ctrl2,
    this.focusCtrl1,
    this.focusCtrl2,
    this.onSalvar,
  });

  final TextEditingController ctrl1;
  final TextEditingController ctrl2;
  final FocusNode? focusCtrl1;
  final FocusNode? focusCtrl2;
  final VoidCallback? onSalvar;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CampoGol(
          controller: ctrl1,
          focusNode: focusCtrl1,
          textInputAction: TextInputAction.next,
          onSubmitted:
              focusCtrl2 != null ? (_) => focusCtrl2!.requestFocus() : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'X',
            style: GoogleFonts.anybody(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Cores.onSurfaceVariant,
            ),
          ),
        ),
        _CampoGol(
          controller: ctrl2,
          focusNode: focusCtrl2,
          textInputAction: TextInputAction.done,
          onSubmitted: onSalvar != null ? (_) => onSalvar!() : null,
        ),
      ],
    );
  }
}

class _CampoGol extends StatelessWidget {
  const _CampoGol({
    required this.controller,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 68,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        focusNode: focusNode,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(2),
        ],
        style: GoogleFonts.hankenGrotesk(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: Cores.onSurface,
          letterSpacing: 1,
        ),
        decoration: InputDecoration(
          hintText: '–',
          hintStyle: GoogleFonts.hankenGrotesk(
            fontSize: 26,
            fontWeight: FontWeight.w300,
            color: Cores.outlineVariant,
          ),
          filled: true,
          // Visual idêntico com ou sem palpite salvo — quem sinaliza o save
          // são a borda verde do card e o cadeado.
          fillColor: Cores.surface,
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Cores.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Cores.azulTerciario, width: 2),
          ),
        ),
      ),
    );
  }
}

class _Time extends StatelessWidget {
  const _Time({required this.nome});

  final String nome;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          // 36px — mesmo tamanho dos cards da tela Tabela
          width: 36,
          height: 36,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Cores.surfaceContainerHigh,
            border: Border.all(color: Cores.outlineVariant),
          ),
          child: Bandeira(nome, tamanho: 36),
        ),
        const SizedBox(height: 4),
        Text(
          nomePtDe(nome),
          style: GoogleFonts.hankenGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Cores.onSurface,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _CabecalhoData extends StatelessWidget {
  const _CabecalhoData({required this.dataChave});

  final String dataChave;

  static const _meses = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];
  static const _dias = [
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];

  @override
  Widget build(BuildContext context) {
    final data = DateTime.parse(dataChave).toLocal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${data.day} de ${_meses[data.month - 1]} de ${data.year} · ${_dias[data.weekday - 1]}',
          style: GoogleFonts.anybody(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Cores.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        const Divider(color: Cores.outlineVariant, height: 1),
      ],
    );
  }
}

class _BotaoVerMais extends StatelessWidget {
  const _BotaoVerMais({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.expand_more_rounded),
      label: Text(
        'VER MAIS',
        style: GoogleFonts.anybody(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Cores.verdePrincipal,
        side: const BorderSide(color: Cores.verdePrincipal),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _FimDaLista extends StatelessWidget {
  const _FimDaLista();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Cores.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Todos os jogos exibidos',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 12,
              color: Cores.onSurfaceVariant,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Cores.outlineVariant)),
      ],
    );
  }
}

// ─── Seletor de modo (MODO CLÁSSICO / MODO COPA) ─────────────────────────────

class _SeletorModo extends StatelessWidget {
  const _SeletorModo({required this.modoClassico, required this.onChanged});
  final bool modoClassico;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Cores.verdePrincipal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _BotaoModo(
            label: 'MODO CLÁSSICO',
            ativo: modoClassico,
            onTap: () => onChanged(true),
          ),
          const SizedBox(width: 8),
          _BotaoModo(
            label: 'MODO COPA',
            ativo: !modoClassico,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _BotaoModo extends StatelessWidget {
  const _BotaoModo({
    required this.label,
    required this.ativo,
    required this.onTap,
  });
  final String label;
  final bool ativo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: ativo ? Colors.white : Colors.transparent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        ),
        child: Text(
          label,
          style: GoogleFonts.anybody(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: ativo ? Cores.verdePrincipal : Colors.white70,
          ),
        ),
      ),
    );
  }
}

// ─── Aba Copa — Próximos (formulário de palpite de classificação) ─────────────

class _AbaCopaProximos extends StatefulWidget {
  const _AbaCopaProximos({
    super.key,
    required this.timesPorGrupo,
    required this.palpites,
    required this.rascunho,
    required this.onRascunho,
    required this.bloqueado,
    required this.onSalvar,
  });

  final Map<String, List<String>> timesPorGrupo;
  final Map<String, Map<String, String?>> palpites;
  final Map<String, Map<String, String?>>? rascunho;
  final void Function(Map<String, Map<String, String?>>) onRascunho;
  final bool bloqueado;
  final Future<void> Function(Map<String, Map<String, String?>>) onSalvar;

  @override
  State<_AbaCopaProximos> createState() => _AbaCopaProximosState();
}

class _AbaCopaProximosState extends State<_AbaCopaProximos> {
  late Map<String, Map<String, String?>> _local;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    // Copia o rascunho não salvo (sobrevive à troca de aba/modo) ou os
    // palpites existentes para edição local
    final r = widget.rascunho;
    _local = {
      for (final k in widget.timesPorGrupo.keys)
        k: Map<String, String?>.from(
          r?[k] ??
              widget.palpites[k] ??
              {'primeiro': null, 'segundo': null, 'terceiro': null},
        ),
    };
    // Registra a referência no pai — toda mutação de _local fica preservada
    widget.onRascunho(_local);
  }

  int get _terceirosCount =>
      _local.values
          .where((m) => m['terceiro'] != null && m['terceiro']!.isNotEmpty)
          .length;

  Future<void> _salvar() async {
    if (_terceirosCount > 8) {
      mostrarMensagem(
        context,
        'Máximo de 8 grupos com 3º colocado. Remova ${_terceirosCount - 8} antes de salvar.',
      );
      return;
    }
    setState(() => _salvando = true);
    try {
      await widget.onSalvar(_local);
      if (!mounted) return;
      mostrarMensagem(context, 'Palpites salvos com sucesso!');
    } catch (_) {
      if (!mounted) return;
      mostrarMensagem(context, 'Erro ao salvar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bloqueado) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 56,
                color: Cores.azulTerciario,
              ),
              const SizedBox(height: 16),
              Text(
                'Palpites encerrados',
                style: GoogleFonts.anybody(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'O primeiro jogo da Copa já começou.\nOs palpites de classificação estão bloqueados.',
                textAlign: TextAlign.center,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 14,
                  color: Cores.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ListView(
          // Padding inferior para o conteúdo não ficar atrás do botão flutuante
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          children: [
            Text(
              'Palpite na classificação de cada grupo.',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 15,
                color: Cores.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    '1º e 2º classificam. 3º apenas nos 8 grupos que avançam.',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 13,
                      color: Cores.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _terceirosCount >= 8
                            ? Cores.verdePrincipal
                            : Cores.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color:
                          _terceirosCount >= 8
                              ? Cores.verdePrincipal
                              : Cores.outlineVariant,
                    ),
                  ),
                  child: Text(
                    '3°: $_terceirosCount/8',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                          _terceirosCount >= 8
                              ? Colors.white
                              : Cores.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...widget.timesPorGrupo.entries.map(
              (entry) => _CardGrupoClassificacao(
                grupo: entry.key,
                times: entry.value,
                palpite: _local[entry.key] ?? {},
                terceiroBloqueado:
                    _local[entry.key]?['terceiro'] == null &&
                    _terceirosCount >= 8,
                onChanged: (pos, time) {
                  if (pos == 'terceiro' &&
                      time != null &&
                      _local[entry.key]?['terceiro'] == null &&
                      _terceirosCount >= 8) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Somente 8 grupos podem ter 3º colocado selecionado',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  setState(() {
                    _local[entry.key] ??= {};
                    _local[entry.key]![pos] = time;
                    for (final outraPos in [
                      'primeiro',
                      'segundo',
                      'terceiro',
                    ]) {
                      if (outraPos != pos &&
                          _local[entry.key]![outraPos] == time) {
                        _local[entry.key]![outraPos] = null;
                      }
                    }
                  });
                },
              ),
            ),
          ],
        ),

        // Botão flutuante quadrado — canto inferior direito
        Positioned(
          right: 20,
          bottom: 24,
          child: _BotaoSalvarCopa(
            salvando: _salvando,
            onTap: _salvando ? null : _salvar,
          ),
        ),
      ],
    );
  }
}

// Card de um grupo na tela de palpite Copa
class _CardGrupoClassificacao extends StatelessWidget {
  const _CardGrupoClassificacao({
    required this.grupo,
    required this.times,
    required this.palpite,
    required this.onChanged,
    this.terceiroBloqueado = false,
  });

  final String grupo;
  final List<String> times;
  final Map<String, String?> palpite;
  final void Function(String posicao, String? time) onChanged;
  final bool terceiroBloqueado;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: _sombraCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Cores.surfaceContainer,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Text(
              'GRUPO $grupo',
              style: GoogleFonts.anybody(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Cores.verdePrincipal,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _DropdownClassificacao(
                  label: '🥇 1º Colocado',
                  times: times,
                  selecionado: palpite['primeiro'],
                  excluir: {palpite['segundo'], palpite['terceiro']},
                  onChanged: (v) => onChanged('primeiro', v),
                ),
                const SizedBox(height: 8),
                _DropdownClassificacao(
                  label: '🥈 2º Colocado',
                  times: times,
                  selecionado: palpite['segundo'],
                  excluir: {palpite['primeiro'], palpite['terceiro']},
                  onChanged: (v) => onChanged('segundo', v),
                ),
                const SizedBox(height: 8),
                _DropdownClassificacao(
                  label: '🥉 3º Colocado (opcional)',
                  times: times,
                  selecionado: palpite['terceiro'],
                  excluir: {palpite['primeiro'], palpite['segundo']},
                  onChanged: (v) => onChanged('terceiro', v),
                  opcional: true,
                  bloqueado: terceiroBloqueado,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownClassificacao extends StatelessWidget {
  const _DropdownClassificacao({
    required this.label,
    required this.times,
    required this.selecionado,
    required this.excluir,
    required this.onChanged,
    this.opcional = false,
    this.bloqueado = false,
  });

  final String label;
  final List<String> times;
  final String? selecionado;
  final Set<String?> excluir;
  final void Function(String?) onChanged;
  final bool opcional;
  final bool bloqueado;

  @override
  Widget build(BuildContext context) {
    final disponiveis =
        times.where((t) => !excluir.contains(t) || t == selecionado).toList();

    return DropdownButtonFormField<String>(
      value: selecionado,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.hankenGrotesk(
          fontSize: 13,
          color: Cores.onSurfaceVariant,
        ),
        filled: true,
        fillColor: Cores.surfaceContainer,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Cores.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Cores.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Cores.azulTerciario, width: 2),
        ),
      ),
      hint: Text(
        bloqueado
            ? 'Limite de 8 atingido'
            : (opcional ? 'Não palpitar' : 'Selecionar time'),
        style: GoogleFonts.hankenGrotesk(
          fontSize: 14,
          color: Cores.outlineVariant,
        ),
      ),
      isExpanded: true,
      items: [
        if (opcional)
          DropdownMenuItem<String>(
            value: null,
            child: Text(
              'Não palpitar',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 14,
                color: Cores.onSurfaceVariant,
              ),
            ),
          ),
        ...disponiveis.map(
          (t) => DropdownMenuItem<String>(
            value: t,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: ClipOval(child: Bandeira(t, tamanho: 24)),
                ),
                const SizedBox(width: 8),
                Text(
                  nomePtDe(t),
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      onChanged: bloqueado ? null : onChanged,
    );
  }
}

// ─── Botão salvar Copa (FAB quadrado) ────────────────────────────────────────

class _BotaoSalvarCopa extends StatelessWidget {
  const _BotaoSalvarCopa({required this.salvando, required this.onTap});
  final bool salvando;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: onTap == null ? Cores.outlineVariant : Cores.azulTerciario,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 72,
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                salvando
                    ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(
                      Icons.save_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                const SizedBox(height: 4),
                Text(
                  'SALVAR',
                  style: GoogleFonts.anybody(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
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

// ─── Aba Copa — Encerrados ────────────────────────────────────────────────────

class _AbaCopaEncerrados extends StatelessWidget {
  const _AbaCopaEncerrados({
    super.key,
    required this.palpites,
    required this.classificacaoReal,
  });

  final Map<String, Map<String, String?>> palpites;
  final Map<String, Map<String, String?>> classificacaoReal;

  static const _ordem = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
  ];

  @override
  Widget build(BuildContext context) {
    if (classificacaoReal.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bar_chart_rounded,
                size: 64,
                color: Cores.outlineVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Classificação não divulgada',
                style: GoogleFonts.anybody(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Cores.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Quando o admin confirmar a classificação dos grupos, seus pontos do MODO COPA aparecerão aqui.',
                textAlign: TextAlign.center,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 14,
                  color: Cores.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Calcula total de pontos somando todos os grupos disponíveis
    int totalPontos = 0;
    for (final letra in _ordem) {
      final real = classificacaoReal[letra];
      if (real == null) continue;
      totalPontos += calcularPontosCopaGrupo(palpites[letra] ?? {}, real);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // Banner de total de pontos
        _BannerTotalCopa(pontos: totalPontos),
        const SizedBox(height: 20),
        // Cards de cada grupo
        for (final letra in _ordem)
          if (classificacaoReal.containsKey(letra))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CardGrupoResultado(
                letra: letra,
                real: classificacaoReal[letra]!,
                palpite: palpites[letra] ?? {},
              ),
            ),
      ],
    );
  }
}

// Banner de total de pontos do Modo Copa
class _BannerTotalCopa extends StatelessWidget {
  const _BannerTotalCopa({required this.pontos});
  final int pontos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Cores.azulTerciario,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MODO COPA — FASE DE GRUPOS',
                  style: GoogleFonts.anybody(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total de pontos',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$pontos pts',
            style: GoogleFonts.anybody(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// Card de resultado de um grupo
class _CardGrupoResultado extends StatelessWidget {
  const _CardGrupoResultado({
    required this.letra,
    required this.real,
    required this.palpite,
  });

  final String letra;
  final Map<String, String?> real;
  final Map<String, String?> palpite;

  @override
  Widget build(BuildContext context) {
    final pontos = calcularPontosCopaGrupo(palpite, real);
    final classificadosReais =
        {
          real['primeiro'],
          real['segundo'],
          real['terceiro'],
        }.whereType<String>().toSet();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: _sombraCard,
      ),
      child: Column(
        children: [
          // Cabeçalho
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Cores.surfaceContainer,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'GRUPO $letra',
                  style: GoogleFonts.anybody(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Cores.azulTerciario,
                    letterSpacing: 0.5,
                  ),
                ),
                _BadgePontosGrupoCopa(pontos: pontos),
              ],
            ),
          ),
          // Linhas de posição
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              children: [
                for (final entry in [
                  ('primeiro', '🥇'),
                  ('segundo', '🥈'),
                  ('terceiro', '🥉'),
                ])
                  if (real[entry.$1] != null || palpite[entry.$1] != null)
                    _LinhaResultadoCopa(
                      medalha: entry.$2,
                      timeReal: real[entry.$1],
                      timePalpite: palpite[entry.$1],
                      classificadosReais: classificadosReais,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Badge de pontos do grupo
class _BadgePontosGrupoCopa extends StatelessWidget {
  const _BadgePontosGrupoCopa({required this.pontos});
  final int pontos;

  @override
  Widget build(BuildContext context) {
    final cor =
        pontos >= 500
            ? Cores.azulTerciario
            : pontos >= 200
            ? const Color(0xFF3B6FD4)
            : pontos > 0
            ? const Color(0xFF7B9FE8)
            : Cores.outlineVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$pontos pts',
        style: GoogleFonts.anybody(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

// Uma linha de resultado: medalha | time real | separador | palpite + indicador
class _LinhaResultadoCopa extends StatelessWidget {
  const _LinhaResultadoCopa({
    required this.medalha,
    required this.timeReal,
    required this.timePalpite,
    required this.classificadosReais,
  });

  final String medalha;
  final String? timeReal;
  final String? timePalpite;
  final Set<String> classificadosReais;

  // Retorna (ícone, cor, pontos) para o indicador do palpite
  (IconData, Color, int) get _indicador {
    if (timePalpite == null) return (Icons.remove, Cores.outlineVariant, 0);
    if (timeReal != null && timePalpite == timeReal) {
      return (Icons.check_rounded, Cores.verdePrincipal, 200);
    }
    if (classificadosReais.contains(timePalpite)) {
      return (Icons.swap_horiz_rounded, Cores.ouro, 100);
    }
    return (Icons.close_rounded, Cores.error, 0);
  }

  @override
  Widget build(BuildContext context) {
    final (icone, cor, pts) = _indicador;
    final semPalpite = timePalpite == null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Medalha
          SizedBox(
            width: 26,
            child: Text(medalha, style: const TextStyle(fontSize: 16)),
          ),
          // Time real
          Expanded(
            child:
                timeReal == null
                    ? Text(
                      '—',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13,
                        color: Cores.outlineVariant,
                      ),
                    )
                    : Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: ClipOval(
                            child: Bandeira(timeReal!, tamanho: 22),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            nomePtDe(timeReal!),
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Cores.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
          ),
          // Separador
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '→',
              style: TextStyle(fontSize: 13, color: Cores.outlineVariant),
            ),
          ),
          // Palpite do usuário
          Expanded(
            child:
                semPalpite
                    ? Text(
                      'Sem palpite',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Cores.outlineVariant,
                      ),
                    )
                    : Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: ClipOval(
                            child: Bandeira(timePalpite!, tamanho: 22),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            nomePtDe(timePalpite!),
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Cores.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
          ),
          // Indicador + pontos
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: cor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icone, size: 12, color: cor),
                if (!semPalpite && pts > 0) ...[
                  const SizedBox(width: 3),
                  Text(
                    '+$pts',
                    style: GoogleFonts.anybody(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: cor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/jogo_service.dart';
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
  bool _recalculando = false;
  // ignore: prefer_final_fields
  bool _recalculandoCopa = false;
  bool _popularandoPlacares = false;
  bool _limpando = false;
  bool _limpandoTeste = false;

  // TEMPORÁRIO — remover após validação
  Future<void> _popularPlacaresTeste() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('[TESTE] Popular Placares 1×0?',
            style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
        content: Text(
          'Insere placar 1×0 em todos os 72 jogos da Fase de Grupos.',
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
            style: FilledButton.styleFrom(backgroundColor: Cores.error),
            child: Text('POPULAR',
                style: GoogleFonts.anybody(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _popularandoPlacares = true);
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      final result = await fn.httpsCallable('popularPlacaresTeste').call();
      if (mounted) mostrarMensagem(context, '${result.data['atualizados']} jogos atualizados.');
    } catch (e) {
      if (mounted) mostrarMensagem(context, 'Erro: $e');
    } finally {
      if (mounted) setState(() => _popularandoPlacares = false);
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
          'Remove documentos de usuários e palpites de contas que foram deletadas do Firebase Auth.',
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
      if (mounted) {
        mostrarMensagem(
          context,
          'Limpeza concluída: $usuarios usuário(s) e $palpites palpite(s) órfão(s) removido(s).',
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
          // TEMPORÁRIO — remover após validação
          _CardOpcao(
            icone: Icons.sports_soccer_rounded,
            corIcone: Cores.error,
            titulo: '[TESTE] Popular Placares 1×0',
            descricao: 'Insere placar 1×0 em todos os 72 jogos da Fase de Grupos.',
            carregando: _popularandoPlacares,
            onTap: _popularPlacaresTeste,
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
                'Em breve: recalcula pontuação com base na classificação real da fase de grupos.',
            carregando: _recalculandoCopa,
            onTap: _recalcularCopa,
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
                'Remove documentos de usuários e palpites de contas deletadas do Firebase Auth.',
            carregando: _limpando,
            onTap: _limparOrfaos,
          ),
        ],
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


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/cores.dart';

/// Tela admin que lista os documentos da coleção `logs` (escritos pelas
/// Cloud Functions sincronizarApi/mapearJogosApi). Somente leitura; os logs
/// expiram sozinhos após 7 dias via política de TTL no campo expiraEm.
class TelaAdminLogs extends StatelessWidget {
  const TelaAdminLogs({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.background,
      appBar: AppBar(
        backgroundColor: Cores.verdePrincipal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'LOGS',
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('logs')
            .orderBy('criadoEm', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar logs: ${snapshot.error}',
                  style: GoogleFonts.hankenGrotesk(fontSize: 13),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text(
                'Nenhum log registrado nos últimos 7 dias.',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 14,
                  color: Cores.onSurfaceVariant,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _CardLog(dados: docs[i].data()),
          );
        },
      ),
    );
  }
}

class _CardLog extends StatelessWidget {
  const _CardLog({required this.dados});

  final Map<String, dynamic> dados;

  String _formatar(DateTime d) {
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)} '
        '${dois(d.hour)}:${dois(d.minute)}:${dois(d.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final origem = (dados['origem'] as String?) ?? '?';
    final mensagem = (dados['mensagem'] as String?) ?? '';
    final criadoEm = (dados['criadoEm'] as Timestamp?)?.toDate().toLocal();

    final corBadge = switch (origem) {
      'erro' => Cores.error,
      'mapearJogosApi' => Cores.azulTerciario,
      _ => Cores.verdePrincipal,
    };

    return Container(
      decoration: BoxDecoration(
        color: Cores.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Cores.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: corBadge.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  origem,
                  style: GoogleFonts.anybody(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: corBadge,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                criadoEm != null ? _formatar(criadoEm) : '—',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 12,
                  color: Cores.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            mensagem,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 12,
              color: Cores.onSurface,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

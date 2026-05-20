import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/usuario.dart';
import '../services/usuario_service.dart';
import '../utils/avatares.dart';
import '../utils/cores.dart';

class TelaPerfil extends StatelessWidget {
  const TelaPerfil({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Cores.background,
      appBar: AppBar(
        backgroundColor: Cores.surface,
        elevation: 1,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Cores.verdePrincipal),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'MEU PERFIL',
          style: TextStyle(
            color: Cores.verdePrincipal,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<Usuario?>(
        stream: UsuarioService().observarUsuario(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Cores.verdePrincipal));
          }
          final usuario = snapshot.data;
          if (usuario == null) {
            return const Center(child: Text('Perfil não encontrado.'));
          }
          return _PerfilConteudo(usuario: usuario);
        },
      ),
    );
  }
}

class _PerfilConteudo extends StatelessWidget {
  const _PerfilConteudo({required this.usuario});

  final Usuario usuario;

  Future<void> _editarNome(BuildContext context) async {
    final controller = TextEditingController(text: usuario.nome);
    final novoNome = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Cores.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Editar nome',
          style: GoogleFonts.anybody(fontWeight: FontWeight.w800, color: Cores.onSurface),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.hankenGrotesk(color: Cores.onSurface),
          decoration: InputDecoration(
            hintText: 'Seu nome no bolão',
            hintStyle: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Cores.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Cores.verdePrincipal, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: GoogleFonts.hankenGrotesk(color: Cores.onSurfaceVariant)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Cores.verdePrincipal),
            onPressed: () {
              final valor = controller.text.trim();
              if (valor.isNotEmpty) Navigator.of(ctx).pop(valor);
            },
            child: Text('Salvar', style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (novoNome != null && novoNome != usuario.nome) {
      await UsuarioService().atualizarNome(usuario.uid, novoNome);
    }
  }

  void _editarAvatar(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Cores.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SeletorAvatarSheet(
        avatarAtual: usuario.avatar,
        onSelecionado: (id) async {
          Navigator.of(context).pop();
          await UsuarioService().atualizarAvatar(usuario.uid, id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const meses = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
        'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
    final data = usuario.criadoEm.toLocal();
    final membroDesde = '${meses[data.month - 1]} de ${data.year}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
      children: [
        // Avatar com botão de editar
        Center(
          child: GestureDetector(
            onTap: () => _editarAvatar(context),
            child: Stack(
              children: [
                WidgetAvatar(
                  avatarId: usuario.avatar,
                  nome: usuario.nome,
                  tamanho: 90,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Cores.verdePrincipal,
                      shape: BoxShape.circle,
                      border: Border.all(color: Cores.background, width: 2),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Card de dados
        Container(
          decoration: BoxDecoration(
            color: Cores.surface,
            border: Border.all(color: Cores.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _CampoInfo(
                icone: Icons.person_outline_rounded,
                label: 'Nome',
                valor: usuario.nome,
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: Cores.verdePrincipal),
                  onPressed: () => _editarNome(context),
                  tooltip: 'Editar nome',
                ),
              ),
              const Divider(height: 1, color: Cores.outlineVariant, indent: 16, endIndent: 16),
              _CampoInfo(
                icone: Icons.email_outlined,
                label: 'E-mail',
                valor: usuario.email,
              ),
              const Divider(height: 1, color: Cores.outlineVariant, indent: 16, endIndent: 16),
              _CampoInfo(
                icone: Icons.calendar_today_outlined,
                label: 'Membro desde',
                valor: membroDesde,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Card de pontuação
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Cores.verdePrincipal,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 32),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pontuação total',
                    style: GoogleFonts.hankenGrotesk(fontSize: 13, color: Colors.white70),
                  ),
                  Text(
                    '${usuario.pontuacao} pts',
                    style: GoogleFonts.anybody(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Bottom sheet de seleção de avatar ───────────────────────────────────────

class _SeletorAvatarSheet extends StatefulWidget {
  const _SeletorAvatarSheet({required this.avatarAtual, required this.onSelecionado});

  final String? avatarAtual;
  final void Function(String) onSelecionado;

  @override
  State<_SeletorAvatarSheet> createState() => _SeletorAvatarSheetState();
}

class _SeletorAvatarSheetState extends State<_SeletorAvatarSheet> {
  late String? _selecionado;

  @override
  void initState() {
    super.initState();
    _selecionado = widget.avatarAtual;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      builder: (_, scrollController) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Cores.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'ESCOLHA SEU AVATAR',
            style: GoogleFonts.anybody(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Cores.verdePrincipal,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              itemCount: kJogadores.length,
              itemBuilder: (context, index) {
                final jogador = kJogadores[index];
                return CardAvatar(
                  jogador: jogador,
                  selecionado: _selecionado == jogador.id,
                  onTap: () {
                    setState(() => _selecionado = jogador.id);
                    widget.onSelecionado(jogador.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Campo de informação ──────────────────────────────────────────────────────

class _CampoInfo extends StatelessWidget {
  const _CampoInfo({
    required this.icone,
    required this.label,
    required this.valor,
    this.trailing,
  });

  final IconData icone;
  final String label;
  final String valor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icone, size: 20, color: Cores.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Cores.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Cores.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

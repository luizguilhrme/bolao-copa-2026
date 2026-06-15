import 'package:flutter/material.dart';

/// Paleta de cores do Bolão Copa 2026
/// Derivada do design system gerado no Stitch
class Cores {
  Cores._(); // impede instanciação

  // ── Primária (verde) ──────────────────────────────────────────────
  static const Color verdePrincipal = Color(0xFF006D32);
  static const Color primaryContainer = Color(0xFF00D166);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ── Secundária (amarelo) ──────────────────────────────────────────
  static const Color secondaryContainer = Color(0xFFFCD400);
  static const Color onSecondaryContainer = Color(0xFF6E5C00);

  // ── Terciária (azul) ─────────────────────────────────────────────
  static const Color azulTerciario = Color(0xFF004CED);
  // Chip de status AGENDADO nos cards de jogo (Home, Tabela, Teste de API)
  static const Color azulAgendado = Color(0xFF1A7AE8);

  // ── Superfície / fundo ────────────────────────────────────────────
  // Fundo acinzentado: dá profundidade aos cards brancos com sombra suave
  static const Color background = Color(0xFFEFF1F6);
  // Verde bem claro: fundo de filtros/segmentos não selecionados
  static const Color verdeSuave = Color(0xFFE6F2EA);
  static const Color surface = Color(0xFFF9F9FF);
  // Superfícies em tons de verde claro (eram azuladas; trocadas em 2026-06
  // para harmonizar com a identidade verde do app)
  static const Color surfaceVariant = Color(0xFFD3E5DA);
  static const Color surfaceContainer = Color(0xFFE6F2EA);
  static const Color surfaceContainerHigh = Color(0xFFDCEBE1);

  // ── Texto / conteúdo ──────────────────────────────────────────────
  static const Color onSurface = Color(0xFF111C2D);
  static const Color onSurfaceVariant = Color(0xFF3C4A3D);

  // ── Bordas ────────────────────────────────────────────────────────
  static const Color outlineVariant = Color(0xFFBBCBB9);
  static const Color outline = Color(0xFF6C7B6C);

  // ── Erro ─────────────────────────────────────────────────────────
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);

  // ── Badges de pontuação (escala 100/70/60/50/0/negativo) ─────────
  static const Color pontExato = Color(0xFF006D32); // 100 pts
  static const Color pontVencedorSaldo = Color(0xFF1B7F3A); // 70 pts
  static const Color pontVencedorUmTime = Color(0xFF2E7D52); // 60 pts
  static const Color pontVencedor = Color(0xFF4CAF50); // 50 pts
  static const Color pontZero = Color(0xFFBBCBB9); // 0 pts
  static const Color pontNegativo = Color(0xFFE53935); // negativo

  // ── Pódio ─────────────────────────────────────────────────────────
  static const Color ouro = Color(0xFFC69E3B);
  static const Color prata = Color(0xFFC0C0C0);
  static const Color bronze = Color(0xFFCD7F32);

  // ── Ranking (cards de medalha do top 3 + textos) ──────────────────
  // Fundos suaves e bordas dos cards de medalha
  static const Color ouroSuave = Color(0xFFFFF7DE);
  static const Color ouroBorda = Color(0xFFE7C969);
  // Texto/contorno dourado escuro (label LÍDER, contorno da coroa)
  static const Color ouroEscuro = Color(0xFF9C7A1F);
  // Prata mais fria/escura que Cores.prata — selo e anel do 2º lugar
  static const Color prataMedalha = Color(0xFF9AA3AE);
  static const Color prataSuave = Color(0xFFF1F3F6);
  static const Color prataBorda = Color(0xFFCDD3DA);
  static const Color bronzeSuave = Color(0xFFFAEBDD);
  static const Color bronzeBorda = Color(0xFFE2B488);
  // Texto terciário neutro (posições e linha de stats do ranking)
  static const Color cinzaTexto = Color(0xFF7A8794);
}

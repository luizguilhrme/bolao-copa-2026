import 'package:flutter/material.dart';

/// Paleta de cores do Bolão Copa 2026
/// Derivada do design system gerado no Stitch
class Cores {
  Cores._(); // impede instanciação

  // ── Primária (verde) ──────────────────────────────────────────────
  static const Color verdePrincipal    = Color(0xFF006D32);
  static const Color primaryContainer  = Color(0xFF00D166);
  static const Color onPrimary         = Color(0xFFFFFFFF);

  // ── Secundária (amarelo) ──────────────────────────────────────────
  static const Color secondaryContainer    = Color(0xFFFCD400);
  static const Color onSecondaryContainer  = Color(0xFF6E5C00);

  // ── Terciária (azul) ─────────────────────────────────────────────
  static const Color azulTerciario = Color(0xFF004CED);

  // ── Superfície / fundo ────────────────────────────────────────────
  static const Color background           = Color(0xFFF9F9FF);
  static const Color surface              = Color(0xFFF9F9FF);
  static const Color surfaceVariant       = Color(0xFFD8E3FB);
  static const Color surfaceContainer     = Color(0xFFE7EEFF);
  static const Color surfaceContainerHigh = Color(0xFFDEE8FF);

  // ── Texto / conteúdo ──────────────────────────────────────────────
  static const Color onSurface        = Color(0xFF111C2D);
  static const Color onSurfaceVariant = Color(0xFF3C4A3D);

  // ── Bordas ────────────────────────────────────────────────────────
  static const Color outlineVariant = Color(0xFFBBCBB9);
  static const Color outline        = Color(0xFF6C7B6C);

  // ── Erro ─────────────────────────────────────────────────────────
  static const Color error   = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);

  // ── Badges de pontuação (escala 100/70/60/50/0/negativo) ─────────
  static const Color pontExato          = Color(0xFF006D32); // 100 pts
  static const Color pontVencedorSaldo  = Color(0xFF1B7F3A); // 70 pts
  static const Color pontVencedorUmTime = Color(0xFF2E7D52); // 60 pts
  static const Color pontVencedor       = Color(0xFF4CAF50); // 50 pts
  static const Color pontZero           = Color(0xFFBBCBB9); // 0 pts
  static const Color pontNegativo       = Color(0xFFE53935); // negativo

  // ── Pódio ─────────────────────────────────────────────────────────
  static const Color prata  = Color(0xFFC0C0C0);
  static const Color bronze = Color(0xFFCD7F32);
}
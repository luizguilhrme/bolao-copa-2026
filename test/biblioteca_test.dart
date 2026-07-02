// Testes de unidade das funções puras de pontuação de lib/utils/biblioteca.dart.
// Cobrem o Modo Clássico (calcularPontos + multiplicador de fase),
// o Modo Copa (calcularPontosCopaGrupo) e a formatação de pontos.

import 'package:flutter_test/flutter_test.dart';

import 'package:bolao/utils/biblioteca.dart';

void main() {
  group('calcularPontos (Modo Clássico)', () {
    test('placar exato vale 100', () {
      expect(calcularPontos(2, 1, 2, 1), 100);
      expect(calcularPontos(0, 0, 0, 0), 100); // empate exato também
    });

    test('vencedor certo + saldo de gols certo vale 70', () {
      expect(calcularPontos(3, 1, 2, 0), 70);
    });

    test('vencedor certo + gols exatos de um time vale 60', () {
      expect(calcularPontos(2, 0, 2, 1), 60); // acertou os gols do time 1
      expect(calcularPontos(3, 1, 2, 1), 60); // acertou os gols do time 2
    });

    test('apenas vencedor certo vale 50', () {
      expect(calcularPontos(1, 0, 3, 1), 50); // saldo diferente, nenhum gol exato
    });

    test('empate certo com placar errado vale 50', () {
      expect(calcularPontos(1, 1, 2, 2), 50);
    });

    test('resultado errado vale 0', () {
      expect(calcularPontos(2, 1, 1, 2), 0); // inverteu o vencedor
      expect(calcularPontos(1, 1, 2, 1), 0); // palpitou empate, teve vencedor
      expect(calcularPontos(2, 0, 1, 1), 0); // palpitou vencedor, deu empate
    });
  });

  group('multiplicadorFase', () {
    test('fase de grupos e rounds desconhecidos valem x1.0', () {
      expect(multiplicadorFase('Grupo A'), 1.0);
      expect(multiplicadorFase(''), 1.0);
    });

    test('fases eliminatórias', () {
      expect(multiplicadorFase('16 avos de Final'), 1.2);
      expect(multiplicadorFase('Oitavas de Final'), 1.4);
      expect(multiplicadorFase('Quartas de Final'), 1.6);
      expect(multiplicadorFase('Semifinal'), 1.8);
      expect(multiplicadorFase('Disputa de 3º Lugar'), 1.8);
      expect(multiplicadorFase('Final'), 2.0);
    });
  });

  group('calcularPontosComFase', () {
    test('multiplica a base pela fase e arredonda', () {
      expect(calcularPontosComFase(2, 1, 2, 1, 'Final'), 200); // 100 x 2.0
      expect(calcularPontosComFase(2, 0, 2, 1, '16 avos de Final'), 72); // 60 x 1.2
      expect(calcularPontosComFase(3, 1, 2, 0, 'Oitavas de Final'), 98); // 70 x 1.4
      expect(calcularPontosComFase(1, 0, 3, 1, 'Semifinal'), 90); // 50 x 1.8
    });

    test('resultado errado continua 0 em qualquer fase', () {
      expect(calcularPontosComFase(2, 1, 1, 2, 'Final'), 0);
    });

    test('fase de grupos mantém a base', () {
      expect(calcularPontosComFase(2, 1, 2, 1, 'Grupo C'), 100);
    });
  });

  group('calcularPontosCopaGrupo (Modo Copa)', () {
    test('grupo perfeito com 3 classificados: 3x200 + bônus 100', () {
      final palpite = {'primeiro': 'Brazil', 'segundo': 'Morocco', 'terceiro': 'Haiti'};
      final real = {'primeiro': 'Brazil', 'segundo': 'Morocco', 'terceiro': 'Haiti'};
      expect(calcularPontosCopaGrupo(palpite, real), 700);
    });

    test('grupo perfeito com 2 classificados exige terceiro em branco', () {
      final real = {'primeiro': 'Brazil', 'segundo': 'Morocco', 'terceiro': null};
      // terceiro em branco igual ao real: 2x200 + bônus
      expect(
        calcularPontosCopaGrupo(
          {'primeiro': 'Brazil', 'segundo': 'Morocco', 'terceiro': null},
          real,
        ),
        500,
      );
      // palpitou um 3º que não classificou: perde só o bônus
      expect(
        calcularPontosCopaGrupo(
          {'primeiro': 'Brazil', 'segundo': 'Morocco', 'terceiro': 'Haiti'},
          real,
        ),
        400,
      );
    });

    test('classificado em posição errada vale 100', () {
      final palpite = {'primeiro': 'Morocco', 'segundo': 'Brazil', 'terceiro': null};
      final real = {'primeiro': 'Brazil', 'segundo': 'Morocco', 'terceiro': null};
      expect(calcularPontosCopaGrupo(palpite, real), 200); // 2x100, sem bônus
    });

    test('palpite de 3º que classificou em outra posição vale 100 mesmo com vaga real vazia', () {
      final palpite = {'primeiro': 'Haiti', 'segundo': 'Scotland', 'terceiro': 'Brazil'};
      final real = {'primeiro': 'Brazil', 'segundo': 'Morocco', 'terceiro': null};
      expect(calcularPontosCopaGrupo(palpite, real), 100); // só o Brazil classificou
    });

    test('nenhum classificado vale 0', () {
      final palpite = {'primeiro': 'Haiti', 'segundo': 'Scotland', 'terceiro': null};
      final real = {'primeiro': 'Brazil', 'segundo': 'Morocco', 'terceiro': null};
      expect(calcularPontosCopaGrupo(palpite, real), 0);
    });
  });

  group('formatarPontos', () {
    test('separador de milhar pt-BR', () {
      expect(formatarPontos(0), '0');
      expect(formatarPontos(999), '999');
      expect(formatarPontos(1240), '1.240');
      expect(formatarPontos(1234567), '1.234.567');
    });

    test('números negativos', () {
      expect(formatarPontos(-10), '-10');
      expect(formatarPontos(-1240), '-1.240');
    });
  });
}

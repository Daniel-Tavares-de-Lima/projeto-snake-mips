# Projeto SNAKE (Assembly MIPS)

Jogo da cobrinha (Snake) em Assembly MIPS para o simulador MARS 4.5.
Entrada pelo teclado (W/A/S/D) e saida no Bitmap Display do MARS.

## Como rodar

1. Abra o `snake.asm` no MARS.
2. Em **Tools > Bitmap Display**, configure:

   | Campo | Valor |
   |---|---|
   | Unit Width in Pixels | 16 |
   | Unit Height in Pixels | 16 |
   | Display Width in Pixels | 512 |
   | Display Height in Pixels | 512 |
   | Base address for display | `0x10010000 (static data)` |

   Clique em **Connect to MIPS**.
3. Em **Tools > Keyboard and Display MMIO Simulator**, clique em **Connect to MIPS**.
4. Monte (F3) e rode (F5).
5. Clique na caixa **KEYBOARD** do simulador de teclado e jogue com W/A/S/D.
6. A pontuacao final aparece na aba **Run I/O** quando o jogo termina.

## Regras

- A cobra (azul) comeca com 1 celula em (0,0), parada ate a primeira tecla.
- W = cima, A = esquerda, S = baixo, D = direita. A cada 0,5 s ela anda 1 celula na ultima direcao.
- Ao pegar a comida (verde), a cobra cresce 1 celula e a comida reaparece em outra celula livre.
- Pontuacao: +1 a cada 0,5 s e +5 a cada comida.
- Fim de jogo: bater na parede ou em qualquer parte do proprio corpo (inclusive voltar na direcao oposta).

## Como o codigo esta organizado

| Rotina | O que faz |
|---|---|
| `main` / `loop_jogo` | Laco principal: le o teclado o tempo todo e move a cobra a cada 500 ms (syscall 30) |
| `ler_teclado` | Polling do teclado MMIO (`0xFFFF0000`) e atualizacao da direcao |
| `mover_cobra` | Nova cabeca, colisoes, crescimento, deslocamento do corpo e pontuacao |
| `nova_comida` | Sorteia (syscall 42) uma celula livre e desenha a comida |
| `desenha_cobra`, `desenha_celula` | Pintam as celulas no Bitmap Display |
| `game_over` | Imprime a pontuacao final e encerra |

O tabuleiro e uma grade de 32 x 32 celulas (512 / 16). Cada celula e uma palavra de 4 bytes no
Bitmap Display, que fica no inicio do `.data`. O proprio display tambem e usado como mapa de
ocupacao (celula azul = corpo da cobra, preta = livre).

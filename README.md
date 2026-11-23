# Projeto SNAKE

Jogo da cobrinha feito em Assembly MIPS pro trabalho de AOC. Roda no MARS 4.5: o teclado (W A S D) é a entrada e o Bitmap Display é a saída.

## Como rodar

1. Abre o `snake.asm` no MARS.
2. Em Tools > Bitmap Display, configura assim:
   - Unit Width in Pixels: 16
   - Unit Height in Pixels: 16
   - Display Width in Pixels: 512
   - Display Height in Pixels: 512
   - Base address for display: `0x10010000 (static data)`

   Depois clica em Connect to MIPS.
3. Em Tools > Keyboard and Display MMIO Simulator, clica em Connect to MIPS também.
4. Monta (F3) e roda (F5).
5. Clica na caixa KEYBOARD do simulador de teclado e joga com W A S D.

A pontuação final aparece na aba Run I/O quando o jogo acaba.

Se o Bitmap Display ficar cortado na tela, estica a janela pra baixo até a área preta ficar quadrada. Isso acontece quando muda a altura pra 512 e a janela não acompanha.

## Regras

A cobra (azul) começa com 1 célula em (0,0) e fica parada até a primeira tecla. W é cima, A é esquerda, S é baixo e D é direita. A cada 0,5 s ela anda 1 célula na última direção escolhida.

Quando pega a comida (verde), a comida aparece em outra célula livre. Nesta branch (dev) a cobra não cresce e fica sempre com 1 célula. Cada passo vale 1 ponto e cada comida vale 5.

O jogo acaba se a cabeça bater na parede ou em qualquer parte do corpo. Voltar na direção oposta conta, porque a cabeça entra no próprio corpo.

## O código

O tabuleiro tem 32 x 32 células (512 / 16), e cada célula é uma word do Bitmap Display. Por isso o display é a primeira coisa do `.data`, que começa no mesmo endereço, `0x10010000`. As outras variáveis ficam depois dele pra não serem sobrescritas. A cobra fica em dois vetores, `cobra_x` e `cobra_y`, com a cabeça no índice 0.

As rotinas:
- `main` e `loop_jogo`: o loop lê o teclado o tempo todo e só move a cobra quando passam 500 ms (syscall 30), pra não perder tecla.
- `ler_teclado`: faz polling no teclado do MARS (`0xFFFF0000`) e atualiza a direção.
- `mover_cobra`: calcula a nova cabeça, confere as colisões, trata a comida, empurra o corpo e soma os pontos.
- `nova_comida`: sorteia uma célula livre com a syscall 42 e desenha a comida.
- `desenha_cobra` e `desenha_celula`: pintam as células no display.
- `game_over`: imprime a pontuação final e encerra.

Pra saber se uma célula tem cobra, o código lê a cor que o display já guarda nela. Azul é corpo e preto é livre, então não precisa percorrer o vetor.

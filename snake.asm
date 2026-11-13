# ============================================================
# Projeto SNAKE - Assembly MIPS (MARS)
# Passo 1: configurar o Bitmap Display e desenhar celulas
# ============================================================
# Configurar em Tools > Bitmap Display:
#   Unit Width in Pixels:     16
#   Unit Height in Pixels:    16
#   Display Width in Pixels:  512
#   Display Height in Pixels: 512
#   Base address:             0x10010000 (static data)
#   -> clicar em "Connect to MIPS" e depois rodar o programa
#
# Grade do jogo: 512 / 16 = 32 x 32 celulas.
# Cada celula e 1 palavra (4 bytes) na memoria: 32*32*4 = 4096 bytes.

.eqv COR_COBRA 0x000000FF       # azul  (cobra, como na especificacao)
.eqv COR_COMIDA 0x0000FF00      # verde (comida, como na especificacao)

.data
# IMPORTANTE: o display ocupa 0x10010000..0x10010FFF.
# Por isso ele tem que ser a PRIMEIRA coisa do .data; as outras
# variaveis do jogo vem depois dele, senao o jogo "pinta" as proprias variaveis.
display: .space 4096

.text
main:
    # desenha a cabeca da cobra em (0,0) - canto superior esquerdo
    li   $a0, 0                 # x
    li   $a1, 0                 # y
    li   $a2, COR_COBRA         # cor
    jal  desenha_celula

    # desenha uma comida de teste em (5,7)
    li   $a0, 5
    li   $a1, 7
    li   $a2, COR_COMIDA
    jal  desenha_celula

    li   $v0, 10                # syscall 10 = encerrar programa
    syscall

# ------------------------------------------------------------
# desenha_celula(x=$a0, y=$a1, cor=$a2)
# endereco = display + (y*32 + x) * 4
# ------------------------------------------------------------
desenha_celula:
    sll  $t0, $a1, 5            # y * 32   (deslocar 5 bits = multiplicar por 32)
    addu $t0, $t0, $a0          # + x      (indice da celula na grade)
    sll  $t0, $t0, 2            # * 4      (cada celula ocupa 4 bytes)
    la   $t1, display           # endereco base do display
    addu $t0, $t0, $t1          # endereco final da celula
    sw   $a2, 0($t0)            # grava a cor -> o Bitmap Display pinta a celula
    jr   $ra                    # volta para quem chamou

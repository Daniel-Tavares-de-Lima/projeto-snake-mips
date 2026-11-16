# ============================================================
# Projeto SNAKE - Assembly MIPS (MARS)
# Passo 2: estado do jogo na memoria (cobra e comida) + desenho
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
display:  .space 4096

# --- estado do jogo ---
# A cobra e guardada em dois vetores: cobra_x[i] e cobra_y[i].
# O indice 0 e a CABECA; o ultimo indice (tamanho-1) e a CAUDA.
# Maximo de celulas da cobra = 32*32 = 1024 (tabuleiro cheio).
tamanho:  .word 1               # a cobra comeca com 1 celula
cobra_x:  .word 0               # cabeca em (0,0) - canto superior esquerdo
          .space 4092           # resto do vetor (1023 posicoes * 4 bytes)
cobra_y:  .word 0
          .space 4092
comida_x: .word 5               # comida fixa por enquanto (vira aleatoria depois)
comida_y: .word 7

.text
main:
    jal  desenha_cobra
    jal  desenha_comida

    li   $v0, 10                # syscall 10 = encerrar programa
    syscall

# ------------------------------------------------------------
# desenha_cobra: percorre os vetores e pinta as 'tamanho' celulas
#   for (i = 0; i < tamanho; i++) desenha_celula(cobra_x[i], cobra_y[i], AZUL)
# Como chama outra funcao (jal), precisa salvar $ra na pilha.
# ------------------------------------------------------------
desenha_cobra:
    addiu $sp, $sp, -4          # abre espaco na pilha
    sw    $ra, 0($sp)           # guarda o endereco de retorno

    lw    $t2, tamanho          # $t2 = quantas celulas pintar
    li    $t3, 0                # $t3 = i (indice, comeca em 0)
loop_cobra:
    beq   $t3, $t2, fim_cobra   # i == tamanho? terminou
    sll   $t4, $t3, 2           # deslocamento em bytes = i * 4
    lw    $a0, cobra_x($t4)     # x = cobra_x[i]
    lw    $a1, cobra_y($t4)     # y = cobra_y[i]
    li    $a2, COR_COBRA
    jal   desenha_celula        # (desenha_celula so mexe em $t0 e $t1)
    addiu $t3, $t3, 1           # i++
    j     loop_cobra
fim_cobra:
    lw    $ra, 0($sp)           # recupera o endereco de retorno
    addiu $sp, $sp, 4           # fecha o espaco da pilha
    jr    $ra

# ------------------------------------------------------------
# desenha_comida: pinta a celula (comida_x, comida_y) de verde.
# So faz um jal no final, entao usamos 'j' (tail call) e nao
# precisamos salvar $ra: o 'jr $ra' de desenha_celula volta direto
# para quem chamou desenha_comida.
# ------------------------------------------------------------
desenha_comida:
    lw    $a0, comida_x
    lw    $a1, comida_y
    li    $a2, COR_COMIDA
    j     desenha_celula

# ------------------------------------------------------------
# desenha_celula(x=$a0, y=$a1, cor=$a2)
# endereco = display + (y*32 + x) * 4
# Usa apenas $t0 e $t1.
# ------------------------------------------------------------
desenha_celula:
    sll  $t0, $a1, 5            # y * 32   (deslocar 5 bits = multiplicar por 32)
    addu $t0, $t0, $a0          # + x      (indice da celula na grade)
    sll  $t0, $t0, 2            # * 4      (cada celula ocupa 4 bytes)
    la   $t1, display           # endereco base do display
    addu $t0, $t0, $t1          # endereco final da celula
    sw   $a2, 0($t0)            # grava a cor -> o Bitmap Display pinta a celula
    jr   $ra                    # volta para quem chamou

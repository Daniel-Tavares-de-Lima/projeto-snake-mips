# ============================================================
# Projeto SNAKE - Assembly MIPS (MARS)
# Passo 3: leitura do teclado (WASD) via MMIO -> guarda a direcao
# ============================================================
# Tambem abrir Tools > Keyboard and Display MMIO Simulator,
# clicar em "Connect to MIPS" e digitar W/A/S/D na caixa de baixo
# (a caixa "KEYBOARD" precisa estar com o foco para receber as teclas).
#
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
.eqv KBD_CTRL 0xFFFF0000        # bit 0 = 1 quando ha uma tecla esperando
.eqv KBD_DATA 0xFFFF0004        # codigo ASCII da tecla (ler limpa o bit 0)

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
# direcao atual = quanto a cabeca anda em x e em y a cada passo.
# (0,0) = parada (ainda nao apertou nenhuma tecla).
# Atencao: o eixo y cresce PARA BAIXO, entao "cima" e y = -1.
dir_x:    .word 0
dir_y:    .word 0

.text
main:
    jal  desenha_cobra
    jal  desenha_comida

# TESTE do passo 3: fica lendo o teclado e imprime a direcao no
# console (Run I/O) sempre que uma tecla valida for apertada.
# Para parar, use o botao Stop do MARS. Sera substituido no passo 4.
loop_jogo:
    jal  ler_teclado
    beqz $v0, loop_jogo         # nenhuma tecla valida: tenta de novo

    lw   $a0, dir_x
    li   $v0, 1                 # syscall 1 = imprimir inteiro
    syscall
    li   $a0, 32                # 32 = ' '
    li   $v0, 11                # syscall 11 = imprimir caractere
    syscall
    lw   $a0, dir_y
    li   $v0, 1
    syscall
    li   $a0, 10                # 10 = '\n'
    li   $v0, 11
    syscall
    j    loop_jogo

# ------------------------------------------------------------
# ler_teclado -> $v0 = 1 se uma tecla W/A/S/D foi lida (e dir_x/dir_y
#                       foram atualizados), $v0 = 0 caso contrario.
# Teclado MMIO: o simulador escreve a tecla em KBD_DATA e poe 1 no
# bit 0 de KBD_CTRL. Nao ha interrupcao: o programa precisa PERGUNTAR
# (polling) se tem tecla. Ler KBD_DATA zera o bit 0.
# ------------------------------------------------------------
ler_teclado:
    li   $t1, KBD_CTRL
    lw   $t0, 0($t1)            # le o registrador de controle
    andi $t0, $t0, 1            # isola o bit 0
    beqz $t0, sem_tecla         # 0 = ninguem apertou nada

    lw   $t2, 4($t1)            # le a tecla (KBD_DATA = KBD_CTRL + 4)
    ori  $t2, $t2, 0x20         # maiuscula -> minuscula ('W' vira 'w')

    beq  $t2, 'w', tecla_cima
    beq  $t2, 'a', tecla_esq
    beq  $t2, 's', tecla_baixo
    beq  $t2, 'd', tecla_dir
    j    sem_tecla              # outra tecla qualquer: ignora

tecla_cima:
    li   $t4, 0                 # dx
    li   $t5, -1                # dy
    j    grava_direcao
tecla_esq:
    li   $t4, -1
    li   $t5, 0
    j    grava_direcao
tecla_baixo:
    li   $t4, 0
    li   $t5, 1
    j    grava_direcao
tecla_dir:
    li   $t4, 1
    li   $t5, 0
grava_direcao:
    sw   $t4, dir_x
    sw   $t5, dir_y
    li   $v0, 1                 # avisa: houve tecla valida
    jr   $ra
sem_tecla:
    li   $v0, 0
    jr   $ra

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

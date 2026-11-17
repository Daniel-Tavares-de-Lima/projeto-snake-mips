# ============================================================
# Projeto SNAKE - Assembly MIPS (MARS)
# ============================================================
# Abrir DUAS ferramentas (Tools) e clicar em "Connect to MIPS" em cada:
#   - Bitmap Display (configuracao abaixo)
#   - Keyboard and Display MMIO Simulator
# Jogar digitando W/A/S/D na caixa de baixo do simulador de teclado
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
.eqv COR_FUNDO 0x00000000       # preto (usado para apagar a cauda)
.eqv PASSO_MS 500               # a cobra anda a cada 500 ms = 0,5 s
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

# Laco principal. O programa NAO dorme 0,5 s (senao perderia as teclas):
# ele roda o tempo todo lendo o teclado e so move a cobra quando o
# relogio passa do instante guardado em $s0.
#   $s0 = instante (em ms) do proximo movimento
    li   $v0, 30                # syscall 30 = tempo do sistema em ms
    syscall                     # retorna a parte baixa (32 bits) em $a0
    addiu $s0, $a0, PASSO_MS    # proximo movimento daqui a 500 ms
loop_jogo:
    jal  ler_teclado            # atualiza dir_x/dir_y se apertou WASD

    li   $v0, 30
    syscall                     # $a0 = agora (ms)
    subu $t0, $a0, $s0          # agora - proximo (com sinal: aguenta overflow)
    bltz $t0, loop_jogo         # negativo = ainda nao deu 0,5 s: volta a ler

    addiu $s0, $a0, PASSO_MS    # agenda o proximo movimento (agora + 500 ms)
    jal  mover_cobra
    j    loop_jogo

# ------------------------------------------------------------
# mover_cobra: da um passo na direcao (dir_x, dir_y).
#   1) calcula a nova cabeca = cabeca atual + direcao
#   2) apaga a cauda no display
#   3) desloca o vetor: cobra[i] = cobra[i-1], da cauda ate o indice 1
#   4) grava a nova cabeca em cobra[0] e desenha
# Nao anda se a direcao for (0,0) (nenhuma tecla apertada ainda).
# TEMPORARIO: se a nova cabeca sair da grade, a cobra apenas nao anda
# (se deixasse, o sw escreveria fora do display e estragaria a memoria).
# No passo 5 isso vira "game over".
# Registradores: $t5/$t6 = nova cabeca (desenha_celula nao mexe neles).
# ------------------------------------------------------------
mover_cobra:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)

    lw    $t0, dir_x
    lw    $t1, dir_y
    or    $t2, $t0, $t1         # 0 so se dir_x == 0 e dir_y == 0
    beqz  $t2, fim_mover        # parada: nada a fazer

    lw    $t2, cobra_x          # cabeca atual (indice 0)
    lw    $t3, cobra_y
    addu  $t5, $t2, $t0         # nova x = x + dir_x
    addu  $t6, $t3, $t1         # nova y = y + dir_y

    # dentro da grade? 0 <= nova < 32. Truque: comparando SEM sinal,
    # um numero negativo vira um numero enorme e tambem falha o teste.
    sltiu $t2, $t5, 32          # t2 = 1 se (unsigned) nova_x < 32
    beqz  $t2, fim_mover
    sltiu $t2, $t6, 32
    beqz  $t2, fim_mover

    # apaga a cauda (ultimo indice = tamanho - 1)
    lw    $t4, tamanho
    addiu $t4, $t4, -1          # t4 = indice da cauda
    sll   $t7, $t4, 2
    lw    $a0, cobra_x($t7)
    lw    $a1, cobra_y($t7)
    li    $a2, COR_FUNDO
    jal   desenha_celula

    # desloca o corpo: for (i = cauda; i > 0; i--) cobra[i] = cobra[i-1]
loop_desloca:
    blez  $t4, fim_desloca      # i <= 0: terminou
    sll   $t7, $t4, 2           # t7 = i * 4
    addiu $t8, $t7, -4          # t8 = (i-1) * 4
    lw    $t9, cobra_x($t8)
    sw    $t9, cobra_x($t7)     # cobra_x[i] = cobra_x[i-1]
    lw    $t9, cobra_y($t8)
    sw    $t9, cobra_y($t7)     # cobra_y[i] = cobra_y[i-1]
    addiu $t4, $t4, -1
    j     loop_desloca
fim_desloca:
    sw    $t5, cobra_x          # nova cabeca em cobra[0]
    sw    $t6, cobra_y
    move  $a0, $t5
    move  $a1, $t6
    li    $a2, COR_COBRA
    jal   desenha_celula        # desenha so a cabeca nova
fim_mover:
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra

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

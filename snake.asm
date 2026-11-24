# ============================================================
# Projeto SNAKE - Assembly MIPS (MARS)
# Grupo: (preencher com os nomes do grupo)
# ============================================================
# Jogo da cobrinha, controlado com W A S D.
# A cobra anda 1 celula a cada 0,5 s na ultima direcao digitada.
# Pontos: +1 a cada 0,5 s e +5 por comida.
# O jogo acaba se a cobra bater na parede ou no proprio corpo
# Grade: 512 / 16 = 32 x 32 celulas. Cada celula e uma word (4 bytes),
# entao o display ocupa 32 * 32 * 4 = 4096 bytes.

.eqv COR_COBRA 0x000000FF       # azul
.eqv COR_COMIDA 0x0000FF00      # verde
.eqv COR_FUNDO 0x00000000       # preto 
.eqv PASSO_MS 500               # tempo entre dois passos em ms
.eqv KBD_CTRL 0xFFFF0000        # bit 0 = tem tecla esperando
                                # (a tecla em si fica em KBD_CTRL + 4)

.data
# O display comeca em 0x10010000,
display:  .space 4096

# estado do jogo
# cobra_x e cobra_y guardam as celulas da cobra.
# indice 0 = cabeca, ultimo indice (tamanho - 1) = cauda.
# O maximo e 1024 celulas (tabuleiro inteiro).
tamanho:  .word 1               # comeca com 1 
cobra_x:  .word 0               # cabeca comeca em (0,0)
          .space 4092           # resto do vetor (1023 * 4 bytes)
cobra_y:  .word 0
          .space 4092
comida_x: .word 0               # sorteada em nova_comida
comida_y: .word 0
# direcao
# (0,0)
dir_x:    .word 0
dir_y:    .word 0
pontos:   .word 0
msg_fim:  .asciiz "\n=== GAME OVER ===\nPontuacao final: "
msg_nl:   .asciiz "\n"

.text
main:
    jal  desenha_cobra          # primeiro a cobra, pra comida nao nascer em cima
    jal  nova_comida

# Loop principal. o loop roda direto lendo o teclado e so move a cobra quando o
# relogio passa de $s0 (instante do proximo passo, em ms).
    li   $v0, 30                # syscall 30 = tempo do sistema em ms
    syscall                     # parte baixa vem em $a0
    addiu $s0, $a0, PASSO_MS    # primeiro passo daqui a 500 ms
loop_jogo:
    jal  ler_teclado

    li   $v0, 30
    syscall                     # $a0 = agora
    subu $t0, $a0, $s0          # agora - proximo (se der negativo, então ainda nao deu o tempo)
    bltz $t0, loop_jogo         # volta a ler o teclado

    addiu $s0, $a0, PASSO_MS    # marca o proximo passo

    lw   $t0, pontos            # +1 ponto por passo
    addiu $t0, $t0, 1
    sw   $t0, pontos

    jal  mover_cobra            # se bater, pula pra game_over
    j    loop_jogo

# ------------------------------------------------------------
# game_over: imprime a pontuacao e encerra o programa.
# ------------------------------------------------------------
game_over:
    la   $a0, msg_fim
    li   $v0, 4                 # 4 = imprimir string
    syscall
    lw   $a0, pontos
    li   $v0, 1                 # 1 = imprimir inteiro
    syscall
    la   $a0, msg_nl
    li   $v0, 4
    syscall
    li   $v0, 10                # 10 = encerrar
    syscall

# ------------------------------------------------------------
# mover_cobra: anda 1 celula na direcao (dir_x, dir_y).
# Calcula a nova cabeca e confere parede e corpo (bateu = game over).
# Depois apaga a cauda, mas caso tenha comido, empurra o vetor e coloca a nova cabeca no indice 0.
# Se a direcao for (0,0) nao faz nada 
# $t5 e $t6 guardam a nova cabeca (desenha_celula so mexe em $t0 e $t1).
# ------------------------------------------------------------
mover_cobra:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)

    lw    $t0, dir_x
    lw    $t1, dir_y
    or    $t2, $t0, $t1         # so da 0 se dir_x e dir_y forem 0
    beqz  $t2, fim_mover        # parada nao faz nada

    lw    $t2, cobra_x          # cabeca atual (indice 0)
    lw    $t3, cobra_y
    addu  $t5, $t2, $t0         # nova x
    addu  $t6, $t3, $t1         # nova y

    # Bateu na parede? O tabuleiro so tem as posicoes de 0 a 31.
    # Se a cobra sai pela esquerda ou por cima, a posicao vira -1;
    # se sai pela direita ou por baixo, vira 32.
    # O sltiu pergunta "e menor que 32?" e trata o -1 como um numero
    # enorme, entao a resposta e "nao" nos dois casos. Um teste so basta.
    sltiu $t2, $t5, 32          # 1 se 0 <= nova x < 32
    beqz  $t2, game_over
    sltiu $t2, $t6, 32
    beqz  $t2, game_over

    # Bateu no corpo? O display ja guarda a cor de cada celula, entao se a
    # celula de destino for azul ja tem cobra ali. Tem que ser antes de
    # apagar a cauda e de desenhar a cabeca nova. 
    sll   $t7, $t6, 5           # mesma conta do desenha_celula
    addu  $t7, $t7, $t5
    sll   $t7, $t7, 2
    la    $t8, display
    addu  $t7, $t7, $t8
    lw    $t9, 0($t7)           # cor da celula de destino
    li    $t8, COR_COBRA
    beq   $t9, $t8, game_over

    # a nova cabeca caiu na comida?
    lw    $t2, comida_x
    lw    $t3, comida_y
    lw    $t4, tamanho
    bne   $t5, $t2, sem_comer
    bne   $t6, $t3, sem_comer
    # comeu: nao apaga a cauda, so aumenta o tamanho
    addiu $t4, $t4, 1
    sw    $t4, tamanho
    j     prepara_desloca
sem_comer:
    # nao comeu: apaga a cauda (indice tamanho - 1)
    addiu $t7, $t4, -1
    sll   $t7, $t7, 2
    lw    $a0, cobra_x($t7)
    lw    $a1, cobra_y($t7)
    li    $a2, COR_FUNDO
    jal   desenha_celula
prepara_desloca:
    addiu $t4, $t4, -1          # t4 = indice da cauda (ja com o tamanho novo)

    # empurra o corpo: for (i = cauda; i > 0; i--) cobra[i] = cobra[i-1]
loop_desloca:
    blez  $t4, fim_desloca
    sll   $t7, $t4, 2           # i * 4
    addiu $t8, $t7, -4          # (i-1) * 4
    lw    $t9, cobra_x($t8)
    sw    $t9, cobra_x($t7)
    lw    $t9, cobra_y($t8)
    sw    $t9, cobra_y($t7)
    addiu $t4, $t4, -1
    j     loop_desloca
fim_desloca:
    sw    $t5, cobra_x          # nova cabeca no indice 0
    sw    $t6, cobra_y
    move  $a0, $t5
    move  $a1, $t6
    li    $a2, COR_COBRA
    jal   desenha_celula        # so a cabeca nova precisa ser desenhada

    # se a cabeca ta em cima da comida, acabou de comer
    lw    $t2, comida_x
    lw    $t3, comida_y
    bne   $t5, $t2, fim_mover
    bne   $t6, $t3, fim_mover
    lw    $t0, pontos
    addiu $t0, $t0, 5           # +5 pela comida
    sw    $t0, pontos
    jal   nova_comida           # so depois de desenhar a cabeca, senao a comida podia cair nela
fim_mover:
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra

# ------------------------------------------------------------
# ler_teclado: se tem uma tecla W/A/S/D esperando, atualiza dir_x e dir_y.
# Outra tecla, ou nenhuma, nao muda nada.
# O teclado nao avisa quando uma tecla e apertada. Quem tem que ir
# olhar e o programa (isso se chama polling), em dois enderecos:
#   KBD_CTRL     -> bit 0 = 1 quer dizer "tem tecla nova"
#   KBD_CTRL + 4 -> qual tecla foi apertada
# Bit 0 igual a 0: nao tem tecla, a funcao sai.
# Bit 0 igual a 1: le a tecla. O MARS zera o bit 0 sozinho na leitura,
# entao a mesma tecla nao e lida duas vezes.
# ------------------------------------------------------------
ler_teclado:
    li   $t1, KBD_CTRL
    lw   $t0, 0($t1)
    andi $t0, $t0, 1            # so o bit 0
    beqz $t0, sem_tecla

    lw   $t2, 4($t1)            # a tecla fica em KBD_CTRL + 4
    ori  $t2, $t2, 0x20         # maiuscula vira minuscula ('W' -> 'w')

    beq  $t2, 'w', tecla_cima
    beq  $t2, 'a', tecla_esq
    beq  $t2, 's', tecla_baixo
    beq  $t2, 'd', tecla_dir
    j    sem_tecla              # qualquer outra tecla e ignorada

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
sem_tecla:
    jr   $ra

# ------------------------------------------------------------
# desenha_cobra: pinta os 'tamanho' celulas da cobra
#   for (i = 0; i < tamanho; i++) desenha_celula(cobra_x[i], cobra_y[i], azul)
# Salva o $ra na pilha porque chama desenha_celula com jal.
# ------------------------------------------------------------
desenha_cobra:
    addiu $sp, $sp, -4
    sw    $ra, 0($sp)

    lw    $t2, tamanho
    li    $t3, 0                # i
loop_cobra:
    beq   $t3, $t2, fim_cobra
    sll   $t4, $t3, 2           # i * 4 (cada posicao do vetor tem 4 bytes)
    lw    $a0, cobra_x($t4)
    lw    $a1, cobra_y($t4)
    li    $a2, COR_COBRA
    jal   desenha_celula
    addiu $t3, $t3, 1
    j     loop_cobra
fim_cobra:
    lw    $ra, 0($sp)
    addiu $sp, $sp, 4
    jr    $ra

# ------------------------------------------------------------
# nova_comida: escolhe uma celula livre, guarda em comida_x e comida_y
# e pinta de verde.
# O sorteio e feito pelo proprio MARS (syscall 42), como um dado: com
# $a1 = 32 ele devolve em $a0 um numero de 0 a 31, diferente a cada vez.
# Sorteia um x e um y. Se a celula nao esta preta, ja tem cobra ali e
# sorteia de novo. Se esta preta, a comida fica nela.
# ------------------------------------------------------------
nova_comida:
sorteia:
    li    $a0, 0
    li    $a1, 32
    li    $v0, 42
    syscall
    move  $t0, $a0              # x
    li    $a0, 0
    li    $a1, 32
    li    $v0, 42
    syscall
    move  $t1, $a0              # y

    sll   $t2, $t1, 5           # mesma conta do desenha_celula
    addu  $t2, $t2, $t0
    sll   $t2, $t2, 2
    la    $t3, display
    addu  $t2, $t2, $t3
    lw    $t4, 0($t2)           # cor da celula sorteada
    bnez  $t4, sorteia          # nao e preta, tem cobra: sorteia outra

    sw    $t0, comida_x
    sw    $t1, comida_y
    move  $a0, $t0
    move  $a1, $t1
    li    $a2, COR_COMIDA
    j     desenha_celula

# ------------------------------------------------------------
# desenha_celula(x = $a0, y = $a1, cor = $a2)
# endereco = display + (y * 32 + x) * 4
# So usa $t0 e $t1.
# ------------------------------------------------------------
desenha_celula:
    sll  $t0, $a1, 5            # y * 32
    addu $t0, $t0, $a0          # + x
    sll  $t0, $t0, 2            # * 4 bytes
    la   $t1, display
    addu $t0, $t0, $t1
    sw   $a2, 0($t0)            # grava a cor e o display pinta a celula
    jr   $ra

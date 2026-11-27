.section .data
.global original_brk
original_brk: .quad 0
atual_brk: .quad 0

.section .text
.global setup_brk, dismiss_brk, memory_alloc, memory_free

# seta os valores iniciais de original_brk e atual_brk
setup_brk:
    pushq %rbp
    movq %rsp, %rbp

    # syscall retorna o valor de brk em rax
    movq $12, %rax
    movq $0, %rdi
    syscall

    # seta as variáveis inicialmente
    movq %rax, original_brk(%rip)
    movq %rax, atual_brk(%rip)

    popq %rbp
    ret

# reseta o brk
dismiss_brk:
    pushq %rbp
    movq %rsp, %rbp

    # chama syscall com o valor do brk original em rdi para resetar
    movq $12, %rax
    movq original_brk(%rip), %rdi
    syscall
    movq %rax, atual_brk(%rip)                  # atualiza atual_brk

    popq %rbp
    ret

# aloca memória. Recebe como parametros o tamanho em bytes do novo bloco (rdi) e o metodo de alocaçao (rsi)
memory_alloc:
    pushq %rbp
    movq %rsp, %rbp

    # r9 guarda o endereço do local mais apropriado a ser inserir o bloco, independente da flag worst/best
    # r11 é o iterador
    movq $0, %r9
    movq original_brk(%rip), %r11

    # compara se a flag worst/best é valida. Se não for, retorna erro
    cmpq $0, %rsi
    je walk_iterator

    cmpq $1, %rsi
    je walk_iterator

    movq $0, %rax
    jmp final

    # caminha pela heap a procura do melhor bloco
    walk_iterator:
        # se o iterador for maior que o final da heap, insere no melhor bloco, presente em r9
        cmpq %r11, atual_brk(%rip)      
        jbe fit

    # verifica se o bloco atual está livre ou não. Se não estiver, já avança para o próximo bloco
    use_comparison:                 
        cmpb $0, (%r11)
        je size_comparison
        addq $1, %r11
        jmp step

    # verifica se o bloco atual tem tamanho maior ou não. Se não tiver, já avança para o próximo bloco
    size_comparison:
        addq $1, %r11
        cmpq %rdi, (%r11)               # r11 tá no inicio do tamanho do bloco
        jge flag_setter             
        jmp step

    # indica a funcao adequada para setar r9, de acordo com a flag de fit
    flag_setter:
        cmpq $1, %rsi
        je best_set

    # define o r9 se a flag de worst/best for 0 e o bloco atual atender às condições
    worst_set:
        cmpq $0, %r9
        je set
        movq 1(%r9), %rcx
        cmpq %rcx, (%r11)
        jle step
        jmp set
        
    # define o r9 se a flag de worst/best for 1 e o bloco atual atender às condições
    best_set:
        cmpq $0, %r9
        je set
        movq 1(%r9), %rcx
        cmpq %rcx, (%r11)
        jge step
        jmp set

    
    # coloca o novo bloco no endereco de r9
    fit:
        # verifica se achou algum bloco aplicável. Se não, adiciona no final da heap
        cmpq $0, %r9
        je add_end

        # seta a flag de uso do novo bloco e verifica se a fragmentação de memória permite criar um bloco vazio apos a nova alocacao (tam restante >= 10)
        # se sim, cria um novo cabecalho. Se nao, mantem o tamanho original do bloco completo no novo bloco alocado (isso nao afeta os dados alocados)
        movb $1, (%r9)          
        addq $1, %r9           
        movq (%r9), %r10        # r10 é usado de reg auxiliar para calcular a diferenca entre os tamanhos dos blocos
        subq %rdi, %r10
        cmpq $10, %r10          
        jl set_adress           
        
        # define o tamanho do novo bloco para o caso de a fragmentação restante ter tamanho >= 10
        movq %rdi, (%r9) 
        movq %r9, %r8           # r8 é usado de reg auxiliar para nao alterar o valor de r9               
        addq $8, %r8
        addq %rdi, %r8
        
        # seta o cabecalho do bloco restante da fragmentacao
        movb $0, (%r8)
        addq $1, %r8
        subq $9, %r10
        movq %r10, (%r8)
        jmp set_adress      

    # adiciona o novo bloco no final da heap
    add_end:
        # atualiza atual_brk com o novo tamanho, define os parametros e chama syscall para aumentar a brk do sistema
        movq %rdi, %r8                  # salva rdi em r8 para nao perder o dado
        addq $9, atual_brk(%rip)        
        addq %r8, atual_brk(%rip)       
        movq atual_brk(%rip), %rdi      
        movq $12, %rax
        syscall                         

        # compara se a alocacao foi bem sucedida. Se nao, trata o erro
        cmpq atual_brk(%rip), %rax      
        jb error_memory
        
        # seta o cabecalho do novo bloco
        subq %r8, %rdi
        subq $9, %rdi
        movb $1, (%rdi)
        addq $1, %rdi
        movq %r8, (%rdi)
        movq %rdi, %r9

        jmp set_adress                  

    # trata o caso de excesso de memória alocada, desfazendo a alocação e retornando erro
    error_memory:
        subq %r8, %rdi                  
        subq $9, %rdi
        movq %rdi, atual_brk(%rip)
        movq $12, %rax
        syscall
        movq $0, %rax
        jmp final

    # função auxiliar de troca da variavel auxiliar r9. Economia de código
    set:
        subq $1, %r11
        movq %r11, %r9
        addq $1, %r11
        jmp step

    # avança para o proximo bloco. Economia de código
    step: 
        addq (%r11), %r11
        addq $8, %r11           # altera o r11 para o inicio do proximo bloco
        jmp walk_iterator


    # define o endereço a ser retornado no caso de sucesso: início dos dados do novo bloco
    set_adress:
        addq $8, %r9
        movq %r9, %rax
        jmp final    

# libera memoria alocada. Recebe como parametro um ponteiro para o inicio dos dados do bloco que se deseja liberar (rdi)
memory_free:
    pushq %rbp
    movq %rsp, %rbp

    # como o ponteiro aponta para o inicio dos dados, é necessario subtrair 9 para chegar ao inicio do cabecalho
    subq $9, %rdi
  
    # verifica se o ponteiro esta fora da heap. Se estiver, nao desaloca e retorna erro
    cmpq %rdi, original_brk(%rip)
    ja illegal_free

    cmpq %rdi, atual_brk(%rip)
    jbe illegal_free

    # seta a flag de uso do bloco desalocado
    movb $0, (%rdi)
    jmp set_ret

    # trata o caso em que o ponteiro esta fora da heap retornando erro   
    illegal_free:
        movq $0, %rax
        jmp final

    # define o retorno em caso de sucesso
    set_ret:
        movq $1, %rax

# retorna para a main
final:
    popq %rbp
    ret


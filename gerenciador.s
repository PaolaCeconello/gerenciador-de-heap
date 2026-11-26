.section .data
.global original_brk
original_brk: .quad 0
atual_brk: .quad 0

.section .text
.global setup_brk, dismiss_brk, memory_alloc, memory_free

setup_brk:
    pushq %rbp
    movq %rsp, %rbp

    movq $12, %rax
    movq $0, %rdi
    syscall
    movq %rax, original_brk(%rip)
    movq %rax, atual_brk(%rip)

    popq %rbp
    ret

dismiss_brk:
    pushq %rbp
    movq %rsp, %rbp

    movq $12, %rax
    movq original_brk(%rip), %rdi
    syscall
    movq %rax, atual_brk(%rip)

    popq %rbp
    ret

memory_alloc:
    pushq %rbp
    movq %rsp, %rbp

    # compara se a heap está vazia. Se estiver, adiciona no final
    movq original_brk(%rip), %rdx
    cmpq %rdx, atual_brk(%rip)
    je add_end

    # r9 guarda o endereço do local mais apropriado a ser inserir o bloco, independente da flag worst/best_fit
    # r11 é o iterador
    movq $0, %r9
    movq original_brk(%rip), %r11

    # compara se a flag worst/best é valida
    cmpq $0, %rsi
    je walk_iterator

    cmpq $1, %rsi
    je walk_iterator

    movq $0, %rax
    jmp final

    # adiciona o novo bloco no final da heap
    add_end:
        movq atual_brk(%rip), %r10
        movb $1, (%r10)                 # insere a flag de "ocupado" no primeiro byte
        addq $1, atual_brk(%rip)        
        movq atual_brk(%rip), %r10  
        movq %rdi, (%r10)               # insere o tamanho de bytes nos proximos 8 bytes
        addq $8, atual_brk(%rip)
        addq %rdi, atual_brk(%rip)      # aumenta atual_brk com o tamanho do bloco

        movq $12, %rax
        movq atual_brk(%rip), %rdi      
        syscall                         # aumenta a brk real

        movq atual_brk(%rip), %r9
        subq %rdi, %r9
        subq $8, %r9

        jmp set_adress                  # neste caso, o set adress tem que ser atual_brk - rdi


    # caminha pela heap a procura do melhor bloco
    walk_iterator:
        cmpq %r11, atual_brk(%rip)      # se o iterador for maior que o final da heap, insere no melhor bloco, presente em r9
        jbe fit

    # verifica se o bloco atual está livre ou não. Se não estiver, já avança para o próximo bloco
    use_comparison:                 
        cmpq $0, (%r11)
        je size_comparison
        addq $1, %r11
        addq (%r11), %r11
        addq $8, %r11
        jmp walk_iterator

    # verifica se o bloco atual tem tamanho maior ou não. Se não tiver, já avança para o próximo bloco
    size_comparison:
        addq $1, %r11
        cmpq %rdi, (%r11)               # r11 tá no inicio do tamanho
        jge flag_setter             
        addq (%r11), %r11
        addq $8, %r11
        jmp walk_iterator

    # seta r9 se possivel
    flag_setter:
        cmpq $0, %rsi
        je worst_set
        jmp best_set

    # define o r9 se a flag de worst/best for 0 e o bloco atual atender às condições
    worst_set:
        cmpq $0, %r9
        je set
        movq (%r9), %rcx
        cmpq %rcx, (%r11)
        jle step
        jmp set
        
    # define o r9 se a flag de worst/best for 1 e o bloco atual atender às condições
    best_set:
        cmpq $0, %r9
        je set
        movq (%r9), %rcx
        cmpq %rcx, (%r11)
        jge step
        jmp set
    
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

    # coloca o novo bloco no endereco de r9
    fit:
        cmpq $0, %r9            # não achou bloco
        je add_end

        movb $1, (%r9)          # seta a flag de uso do novo bloco
        addq $1, %r9            # pula para o inicio do tamanho do bloco
        movq (%r9), %r10          
        subq %rdi, %r10         # calcula a diferenca de bytes entre os dois para verificar se é possivel criar um novo bloco vazio
        cmpq $10, %r10          
        jl set_adress           # neste caso, o adress tem que ser r9 + 8          
        movq %rdi, (%r9)        
        jmp set_adress      

    set_adress:
        addq $8, %r9
        movq %r9, %rax
        jmp final    

memory_free:
    pushq %rbp
    movq %rsp, %rbp

    movq %rdi, %r8
    subq $8, %rdi
    movq (%rdi), %r10
    subq $1, %rdi

    cmpq %rdi, original_brk(%rip)
    ja illegal_free

    cmpq %rdi, atual_brk(%rip)
    jbe illegal_free

    addq %r10, %r8
    cmpq %r8, atual_brk(%rip)
    je free_end

    movb $0, (%rip)
    jmp set_ret

    illegal_free:
        movq $0, %rax
        jmp final

    free_end:
        movq $12, %rax
        syscall
        movq %rdi, atual_brk(%rip)

    set_ret:
        movq $1, %rax

    final:
        popq %rbp
        ret
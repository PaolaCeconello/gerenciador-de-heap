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
        movq %rdi, %r8
        addq $9, atual_brk(%rip)
        addq %r8, atual_brk(%rip)
        movq atual_brk(%rip), %rdi
        movq $12, %rax
        syscall

        cmpq atual_brk(%rip), %rax
        jb error_memory
        
        subq %r8, %rdi
        subq $9, %rdi
        movb $1, (%rdi)
        addq $1, %rdi
        movq %r8, (%rdi)
        movq %rdi, %r9

        jmp set_adress                  # neste caso, o set adress é o r9 + 8

    # trata o caso de excesso de memória alocada, desfazendo a alocação e retornando erro
    error_memory:
        subq %r8, %rdi
        subq $9, %rdi
        movq %rdi, atual_brk(%rip)
        movq $12, %rax
        syscall
        movq $0, %rax
        jmp final

    # caminha pela heap a procura do melhor bloco
    walk_iterator:
        cmpq %r11, atual_brk(%rip)      # se o iterador for maior que o final da heap, insere no melhor bloco, presente em r9
        jbe fit

    # verifica se o bloco atual está livre ou não. Se não estiver, já avança para o próximo bloco
    use_comparison:                 
        cmpb $0, (%r11)
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
        movq %r9, %r8
        addq $8, %r8
        addq %rdi, %r8
        movb $0, (%r8)
        addq $1, %r8
        subq $9, %r10
        movq %r10, (%r8)
        jmp set_adress      

    # define o endereço a ser retornado no caso de sucesso: início dos dados do novo bloco
    set_adress:
        addq $8, %r9
        movq %r9, %rax
        jmp final    

memory_free:
    pushq %rbp
    movq %rsp, %rbp

    subq $9, %rdi
  
    cmpq %rdi, original_brk(%rip)
    ja illegal_free

    cmpq %rdi, atual_brk(%rip)
    jbe illegal_free

    movb $0, (%rdi)
    jmp set_ret

    illegal_free:
        movq $0, %rax
        jmp final

    set_ret:
        movq $1, %rax

    final:
        popq %rbp
        ret


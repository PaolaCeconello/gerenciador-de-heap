.section .data
.global original_brk
original_brkd: .quad 0
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

    cmpq original_brk, atual_brk
    je add_final

    movq $0, %r10
    movq original_brk(%rip), %r11

    cmpq $0, %rsi
    je worst_fit

    cmpq $1, %rsi
    je best_fit

    movq $1, %rax
    jmp final

    add_final:
        movb $1, (atual_brk(%rip))
        movq %rdi, 1(atual_brk(%rip))
        addq $9, %rdi
        addq %rdi, atual_brk(%rip)
        movq $0, %rax
        jmp final

    worst_fit:
        cmpq %r11, atual_brk(%rip)
        jbe add_final

        use_comparison:
            cmpq $0, (%r11)
            je size_comparison
            addq $9, %r11
            addq -8(%r11), %r11
            jmp worst_fit

        size_comparison:
            cmpq %rdi, 1(%r11)
            jge fit
            addq $9, %r11
            addq -8(%r11), %r11
            jmp worst_fit

    best_fit:

    fit:


    final:
        popq %rbp
        ret

memory_free:
    pushq %rbp
    movq %rsp, %rbp

    subq $9, %rdi

    cmpq %rdi, original_brk(%rip)
    ja illegal_free

    cmpq %rdi, atual_brk(%rip)
    jbe illegal_free

    movb $0, (%rdi)
    movq $1, %rax
    jmp final

    illegal_free:
        movq $0, %rax

    final:
        popq %rbp
        ret
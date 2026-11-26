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

    cmpq original_brk(%rip), atual_brk(%rip)
    je add_end

    movq $0, %r9
    movq original_brk(%rip), %r11

    cmpq $0, %rsi
    je walk_iterator

    cmpq $1, %rsi
    je walk_iterator

    movq $1, %rax
    jmp final

    add_end:
        movb $1, (atual_brk(%rip))
        movq %rdi, 1(atual_brk(%rip))
        addq $9, %rdi
        addq %rdi, atual_brk(%rip)
        movq $0, %rax
        jmp final

    walk_iterator:
        cmpq %r11, atual_brk(%rip)
        jbe fit

        use_comparison:
            cmpq $0, (%r11)
            je size_comparison
            addb $1, %r11
            addq (%r11), %r11
            addq $8, %r11
            jmp walk_iterator

        size_comparison:
            addq $1, %r11
            cmpq %rdi, (%r11)
            jge flag_setter
            addb $1, %r11
            addq (%r11), %r11
            addq $8, %r11
            jmp walk_iterator

        flag_setter:
            cmpq $0, %rsi
            je worst_set
            jmp best_set

        step: 
            addb $1, %r11
            addq (%r11), %r11
            addq $8, %r11
            jmp walk_iterator

        worst_set:
            cmpq (%r9), (%r11)

        change_content:
            subb $1, %r11
            movq %r11, %r9
            jmp step

        fit:
            cmpq $1, $rsi
            je best_fit

        worst_fit:
            cmpq $0, %r9
            je add_end
            movb $1, (%r9)
            addb $1, %r9

            movq (%r9), %r8
            subq %rdi, %r8
            cmpq $10, %r8
            jl less_ten_worst

            movq %rdi, (%r9)
            addq %rdi, %r9
            jmp set_ret

        best_fit:
            cmpq $0, %r10
            je add_end
            movb $1, (%r10)
            addb $1, %r10

            movq (%r10), %r8
            subq %rdi, %r8
            cmpq $10, %r8
            jl less_ten_best

            movq %rdi, (%r10)
            addq %rdi, %r10
            jmp set_ret     

    set_ret:
        movq $0, %rax

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
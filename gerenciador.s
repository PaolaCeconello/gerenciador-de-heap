.section .data
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
    movq %rax, original_brk
    movq %rax, atual_brk

    popq %rbp
    ret

dismiss_brk:
    pushq %rbp
    movq %rsp, %rbp

    movq $12, %rax
    movq original_brk, %rdi
    syscall

    popq %rbp
    ret

memory_alloc:
    pushq %rbp
    movq %rsp, %rbp

    popq %rbp
    ret

memory_free:
    pushq %rbp
    movq %rsp, %rbp

    cmpq %rdi, atual_brk
    jge illegal_free

    movq %rdi, %r11
    movb $0, (%r11)
    movq $0, %rax
    jmp final

    illegal_free:
        movq $1, %rax

    final:
        popq %rbp
        ret
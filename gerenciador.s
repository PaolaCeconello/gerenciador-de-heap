.section .data
.global original_brk
original_brkd 0
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
   %rax, atual_brk

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

    subq $9, %rdi

    cmpq %rdi, original_brk(%rip)
    ja illegal_free

   %rdi, atual_brk
    jbe illegal_free

    movb $0, (%rdi)
    movq $1, %rax
    jmp final

    illegal_free:
        movq $0, %rax
        jmp final

    final:
        popq %rbp
        ret
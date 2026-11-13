BITS 64
DEFAULT REL

%define SYS_write 1
%define SYS_exit 60
%define STDOUT 1
%define ARRAY_COUNT 8
%define BUFFER_SIZE 256

section .data
    title db 10, "The Web Machine X v0.0.2", 10, 0
    start_msg db "[WMX] Running tests...", 10, 0
    g1 db 10, "[1] Arithmetic", 10, 0
    g2 db 10, "[2] DIV and IDIV", 10, 0
    g3 db 10, "[3] Logic and bit operations", 10, 0
    g4 db 10, "[4] Control flow", 10, 0
    g5 db 10, "[5] Stack and procedures", 10, 0
    g6 db 10, "[6] Memory and arrays", 10, 0
    g7 db 10, "[7] String instructions", 10, 0
    pass_msg db "PASS", 10, 0
    fail_msg db "FAIL", 10, 0
    done_msg db 10, "[WMX] Test groups complete.", 10, 0
    div_msg db "100 / 9 = ", 0
    rem_msg db " remainder ", 0
    idiv_msg db "-100 / 9 = ", 0
    sum_msg db "Array sum = ", 0
    newline db 10, 0
    minus db "-", 0

    array dq 3, 6, 9, 12, 15, 18, 21, 24
    source db "Web Machine X", 0
    source_len equ $ - source - 1

section .bss
    copy_buffer resb BUFFER_SIZE
    number_buffer resb 32
    failures resq 1
    sum_value resq 1
    last_q resq 1
    last_r resq 1

section .text
global _start

_start:
    lea rsi, [rel title]
    call print_string
    lea rsi, [rel start_msg]
    call print_string
    mov qword [rel failures], 0

    call test_arithmetic
    call test_division
    call test_logic
    call test_control
    call test_stack
    call test_memory
    call test_strings

    lea rsi, [rel done_msg]
    call print_string

    cmp qword [rel failures], 0
    jne .bad
    mov edi, 0
    jmp exit_process
.bad:
    mov edi, 1
    jmp exit_process

; ----------------------------------------------------------------------
; 1. Arithmetic: ADD, SUB, MUL, IMUL, INC, DEC, NEG, CMP, TEST
; ----------------------------------------------------------------------
test_arithmetic:
    lea rsi, [rel g1]
    call print_string

    mov rax, 84
    add rax, 7
    cmp rax, 91
    jne .fail

    sub rax, 14
    cmp rax, 77
    jne .fail

    mov rax, 7
    mul qword [rel divisor7]
    cmp rax, 49
    jne .fail
    test rdx, rdx
    jne .fail

    mov rax, -12
    imul rax, 5
    cmp rax, -60
    jne .fail

    mov rax, 9
    inc rax
    dec rax
    cmp rax, 9
    jne .fail

    neg rax
    cmp rax, -9
    jne .fail

    mov rax, 0b1010
    test rax, 0b0010
    jz .fail

    call report_pass
    ret
.fail:
    call report_fail
    ret

; ----------------------------------------------------------------------
; 2. Unsigned DIV and signed IDIV
; DIV uses RDX:RAX as dividend. Clear RDX for a simple 64-bit dividend.
; IDIV uses a signed RDX:RAX dividend. CQO sign-extends RAX into RDX:RAX.
; ----------------------------------------------------------------------
test_division:
    lea rsi, [rel g2]
    call print_string

    mov rax, 100
    xor edx, edx
    mov rcx, 9
    div rcx
    mov [rel last_q], rax
    mov [rel last_r], rdx
    cmp rax, 11
    jne .fail
    cmp rdx, 1
    jne .fail

    lea rsi, [rel div_msg]
    call print_string
    mov rax, [rel last_q]
    call print_u64
    lea rsi, [rel rem_msg]
    call print_string
    mov rax, [rel last_r]
    call print_u64
    call print_newline

    mov rax, -100
    cqo
    mov rcx, 9
    idiv rcx
    cmp rax, -11
    jne .fail
    cmp rdx, -1
    jne .fail

    lea rsi, [rel idiv_msg]
    call print_string
    mov rax, -11
    call print_i64
    call print_newline

    call report_pass
    ret
.fail:
    call report_fail
    ret

; ----------------------------------------------------------------------
; 3. Logic and bit operations: AND, OR, XOR, NOT, shifts, rotates, BT
; ----------------------------------------------------------------------
test_logic:
    lea rsi, [rel g3]
    call print_string

    mov rax, 0b1100
    and rax, 0b1010
    cmp rax, 0b1000
    jne .fail

    mov rax, 0b1100
    or rax, 0b0011
    cmp rax, 0b1111
    jne .fail

    xor rax, 0b0101
    cmp rax, 0b1010
    jne .fail

    mov al, 0b00001111
    not al
    cmp al, 0b11110000
    jne .fail

    mov rax, 3
    shl rax, 2
    cmp rax, 12
    jne .fail
    shr rax, 2
    cmp rax, 3
    jne .fail

    mov rax, -16
    sar rax, 2
    cmp rax, -4
    jne .fail

    mov al, 0b10000001
    rol al, 1
    cmp al, 0b00000011
    jne .fail
    ror al, 1
    cmp al, 0b10000001
    jne .fail

    mov rax, 8
    bt rax, 3
    jnc .fail

    mov rax, 0
    bts rax, 5
    cmp rax, 32
    jne .fail
    btr rax, 5
    test rax, rax
    jne .fail

    call report_pass
    ret
.fail:
    call report_fail
    ret

; ----------------------------------------------------------------------
; 4. Control flow: CMP, conditional jumps, LOOP, CMOV, SETcc
; ----------------------------------------------------------------------
test_control:
    lea rsi, [rel g4]
    call print_string

    mov rax, 20
    cmp rax, 20
    jne .fail

    mov rax, -2
    cmp rax, 3
    jge .fail

    mov rcx, 5
    xor rax, rax
.loop:
    inc rax
    loop .loop
    cmp rax, 5
    jne .fail

    mov rax, 10
    mov rbx, 20
    cmp rax, rbx
    cmovl rax, rbx
    cmp rax, 20
    jne .fail

    mov rax, 7
    cmp rax, 7
    sete dl
    cmp dl, 1
    jne .fail

    call report_pass
    ret
.fail:
    call report_fail
    ret

; ----------------------------------------------------------------------
; 5. Stack and procedures: PUSH, POP, CALL, RET
; System V AMD64 integer args: RDI, RSI, RDX, RCX, R8, R9; result RAX.
; ----------------------------------------------------------------------
test_stack:
    lea rsi, [rel g5]
    call print_string

    mov rax, 1234
    push rax
    xor rax, rax
    pop rax
    cmp rax, 1234
    jne .fail

    mov rdi, 20
    mov rsi, 22
    call add_two
    cmp rax, 42
    jne .fail

    call report_pass
    ret
.fail:
    call report_fail
    ret

add_two:
    push rbp
    mov rbp, rsp
    mov rax, rdi
    add rax, rsi
    pop rbp
    ret

; ----------------------------------------------------------------------
; 6. Memory: MOV, LEA, indexed addressing, MOVZX, MOVSX
; ----------------------------------------------------------------------
test_memory:
    lea rsi, [rel g6]
    call print_string

    lea rsi, [rel array]
    xor rax, rax
    xor rcx, rcx
.sum:
    add rax, [rsi + rcx*8]
    inc rcx
    cmp rcx, ARRAY_COUNT
    jne .sum
    cmp rax, 108
    jne .fail
    mov [rel sum_value], rax

    lea rsi, [rel sum_msg]
    call print_string
    mov rax, [rel sum_value]
    call print_u64
    call print_newline

    mov byte [rel copy_buffer], 0xFE
    movzx rax, byte [rel copy_buffer]
    cmp rax, 254
    jne .fail

    mov byte [rel copy_buffer], -2
    movsx rax, byte [rel copy_buffer]
    cmp rax, -2
    jne .fail

    lea rax, [rel array]
    test rax, rax
    jz .fail

    call report_pass
    ret
.fail:
    call report_fail
    ret

; ----------------------------------------------------------------------
; 7. String instructions: CLD, REP MOVSB, REPE CMPSB, REPNE SCASB
; ----------------------------------------------------------------------
test_strings:
    lea rsi, [rel g7]
    call print_string

    cld
    lea rsi, [rel source]
    lea rdi, [rel copy_buffer]
    mov rcx, source_len
    rep movsb
    mov byte [rel copy_buffer + source_len], 0

    lea rsi, [rel source]
    lea rdi, [rel copy_buffer]
    mov rcx, source_len
    repe cmpsb
    jne .fail

    lea rdi, [rel copy_buffer]
    xor eax, eax
    mov rcx, BUFFER_SIZE
    repne scasb
    jnz .fail

    call report_pass
    ret
.fail:
    call report_fail
    ret

; ----------------------------------------------------------------------
; Output helpers. Linux write syscall: RAX=1, RDI=fd, RSI=buffer, RDX=len.
; ----------------------------------------------------------------------
print_string:
    push rbx
    mov rbx, rsi
    xor edx, edx
.count:
    cmp byte [rbx + rdx], 0
    je .write
    inc rdx
    jmp .count
.write:
    mov eax, SYS_write
    mov edi, STDOUT
    mov rsi, rbx
    syscall
    pop rbx
    ret

print_newline:
    lea rsi, [rel newline]
    jmp print_string

report_pass:
    push rsi
    lea rsi, [rel pass_msg]
    call print_string
    pop rsi
    ret

report_fail:
    inc qword [rel failures]
    push rsi
    lea rsi, [rel fail_msg]
    call print_string
    pop rsi
    ret

; Print unsigned integer in RAX as decimal.
; DIV is also used internally here to extract base-10 digits.
print_u64:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    lea rsi, [rel number_buffer + 31]
    mov byte [rsi], 10
    mov rcx, 1
    mov ebx, 10
    test rax, rax
    jnz .digits
    dec rsi
    mov byte [rsi], '0'
    inc rcx
    jmp .emit
.digits:
    xor edx, edx
    div rbx
    add dl, '0'
    dec rsi
    mov [rsi], dl
    inc rcx
    test rax, rax
    jnz .digits
.emit:
    mov eax, SYS_write
    mov edi, STDOUT
    mov rdx, rcx
    syscall

    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

print_i64:
    test rax, rax
    jns print_u64
    push rax
    push rsi
    lea rsi, [rel minus]
    call print_string
    pop rsi
    pop rax
    neg rax
    jmp print_u64

exit_process:
    mov eax, SYS_exit
    syscall

section .data
divisor7 dq 7

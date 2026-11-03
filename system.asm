sys_write equ 1
sys_exit equ 60
stdout equ 1

section .data
   msg db "Welcome...", 10, "The Web Machine X", 10, "v0.0.1", 10
   len equ $ - msg
section .text
   global _start

_start:
   mov rax, sys_write
   mov rdi, stdout
   mov rsi, msg
   mov rdx, len
   syscall

   mov rax, sys_exit
   mov rdi, 0
   syscall

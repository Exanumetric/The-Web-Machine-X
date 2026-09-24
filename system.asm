section .data
   msg db "Welcome", 10
   len equ $ - msg
section .text
   global _start

_start:
   mov eax, 1
   mov edi, 1
   mov rsi, msg
   mov edx, len
   syscall

   mov eax, 60
   xor edi, edi
   syscall

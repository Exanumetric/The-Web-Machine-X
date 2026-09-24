[org 0x7c00]            ; BIOS loads the bootloader at this memory address

    mov cx, 24          ; Set our loop counter to 24 lines

print_loop_24:
    push cx             ; Save the current counter (BIOS interrupts might change CX)
    
    mov si, msg         ; Point to our "Welcome" string
    call print_string   ; Print the string
    call print_newline  ; Move the cursor to the next line
    
    pop cx              ; Restore our loop counter
    dec cx              ; Subtract 1 from the counter
    jnz print_loop_24   ; If counter is not zero, repeat the loop

halt:
    jmp $               ; Infinite loop to safely halt execution once finished

; --- Functions ---

print_string:
    mov ah, 0x0e        ; BIOS teletype function
.next_char:
    lodsb               ; Load byte from SI into AL, increment SI
    cmp al, 0           ; Check for null terminator
    je .done            ; If 0, string is finished
    int 0x10            ; Call BIOS video interrupt to print character
    jmp .next_char
.done:
    ret

print_newline:
    mov ah, 0x0e        ; BIOS teletype function
    mov al, 0x0d        ; Carriage Return (\r) - moves cursor to start of line
    int 0x10
    mov al, 0x0a        ; Line Feed (\n) - moves cursor down one line
    int 0x10
    ret


msg: db 'Welcome', 0

times 510-($-$$) db 0   ; Pad remaining bytes with zeroes up to byte 510
dw 0xaa55               ; Standard MBR boot signature

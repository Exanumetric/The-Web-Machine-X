[org 0x7c00]            

    mov cx, 24          

print_loop_24:
    push cx             
    
    mov si, msg         
    call print_string   
    call print_newline  
    
    pop cx              
    dec cx              
    jnz print_loop_24   

halt:
    jmp $               

print_string:
    mov ah, 0x0e        
.next_char:
    lodsb               
    cmp al, 0           
    je .done            
    int 0x10            
    jmp .next_char
.done:
    ret

print_newline:
    mov ah, 0x0e        
    mov al, 0x0d        
    int 0x10
    mov al, 0x0a        
    int 0x10
    ret


msg: db 'Welcome', 0

times 510-($-$$) db 0   
dw 0xaa55              

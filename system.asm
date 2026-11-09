global _start

%macro PRINT 1
    lea rsi, [rel %1]
    call print_line
%endmacro

%macro MATCH 2
    lea rdi, [rel command]
    lea rsi, [rel %1]
    call compare_strings
    test eax, eax
    jz %2
%endmacro

section .data
	prompt db 'WMX> '
	welcome db 'The Web Machine X v0.0.2',0
	help_text db 'HELP       Show commands',10,'STATUS     Show system state',10,'MEMORY     Show simulated memory',10,'PROCESS    Show simulated processes',10,'START      Start simulator',10,'STOP       Stop simulator',10,'CPU        Show simulated CPU',10,'DISK       Show simulated disk',10,'CHECK      Run system check',10,'ABOUT      About this simulator',10,'VERSION    Show version',10,'RESET      Reset simulator',10,'CLEAR      Clear terminal',10,'SHUTDOWN   Exit simulator',0
	status_title db 'SYSTEM STATUS',0
	status_running db 'State: RUNNING',0
	status_stopped db 'State: STOPPED',0
	memory_text db 'MEMORY STATUS',10,'Total: 16 GB (simulated)',10,'Used: 5 GB (simulated)',10,'Free: 11 GB (simulated)',0
	process_text db 'PROCESS TABLE',10,'PID 001  WMX-KERNEL  RUNNING',10,'PID 002  WMX-SHELL   RUNNING',10,'PID 003  WMX-MONITOR IDLE',0
	cpu_text db 'CPU STATUS',10,'Processor: Generic x86-64 (simulated)',10,'Load: 12 percent (simulated)',10,'Logical cores: 8 (simulated)',0
	disk_text db 'DISK STATUS',10,'Device: WMX-VIRTUAL-DISK',10,'Capacity: 256 GB (simulated)',10,'Available: 180 GB (simulated)',0
	check_text db 'SYSTEM CHECK',10,'[OK] Command interface',10,'[OK] Simulator state',10,'[OK] Virtual memory model',10,'[OK] Virtual disk model',10,'No simulated faults found.',0
	about_text db 'Web Machine X is a user-space system simulator.',10,'Hardware values are illustrative, not live telemetry.',0
	version_text db 'Web Machine X System Simulator version 0.0.2',0
	started_text db 'System started.',0
	stopped_text db 'System stopped.',0
	reset_text db 'Simulator state reset.',0
	shutdown_text db 'Shutting down Web Machine X simulator.',0
	unknown_text db 'Unknown command. Type HELP.',0
	input_error db 'Input ended. Exiting simulator.',0
	clear_code db 27,'[2J',27,'[H',0
	newline db 10

section .bss
	command resb 32
	input_char resb 1
	system_running resd 1

section .rodata
	cmd_help db 'HELP',0
	cmd_status db 'STATUS',0
	cmd_memory db 'MEMORY',0
	cmd_process db 'PROCESS',0
	cmd_start db 'START',0
	cmd_stop db 'STOP',0
	cmd_cpu db 'CPU',0
	cmd_disk db 'DISK',0
	cmd_check db 'CHECK',0
	cmd_about db 'ABOUT',0
	cmd_version db 'VERSION',0
	cmd_reset db 'RESET',0
	cmd_clear db 'CLEAR',0
	cmd_shutdown db 'SHUTDOWN',0

section .text
_start:
    ; Avoid blocking forever when the sandbox provides no stdin data.
    mov eax, 72                     ; fcntl
    xor edi, edi                    ; stdin
    mov esi, 4                      ; F_SETFL
    mov edx, 0x800                  ; O_NONBLOCK
    syscall

    mov dword [rel system_running], 1
    PRINT welcome

main_loop:
    mov eax, 1
    mov edi, 1
    lea rsi, [rel prompt]
    mov edx, 5
    syscall

    xor r12d, r12d                 ; command length
    xor r13d, r13d                 ; set after the first word
.read_input:
    xor eax, eax
    xor edi, edi
    lea rsi, [rel input_char]
    mov edx, 1
    syscall
    test rax, rax
    jle input_finished

    mov al, [rel input_char]
    cmp al, 10
    je .line_done
    cmp al, 13
    je .read_input
    cmp al, 32
    jbe .whitespace
    test r13d, r13d
    jnz .read_input
    cmp r12d, 31
    jae .read_input
    lea rdi, [rel command]
    mov [rdi+r12], al
    inc r12d
    jmp .read_input

.whitespace:
    test r12d, r12d
    jz .read_input
    mov r13d, 1
    jmp .read_input

.line_done:
    lea rdi, [rel command]
    mov byte [rdi+r12], 0
    test r12d, r12d
    jz main_loop
    call dispatch_command
    test eax, eax
    jnz main_loop
    jmp exit_program

input_finished:
    PRINT input_error

exit_program:
    mov eax, 60
    xor edi, edi
    syscall

dispatch_command:
    MATCH cmd_help, command_help
    MATCH cmd_status, command_status
    MATCH cmd_memory, command_memory
    MATCH cmd_process, command_process
    MATCH cmd_start, command_start
    MATCH cmd_stop, command_stop
    MATCH cmd_cpu, command_cpu
    MATCH cmd_disk, command_disk
    MATCH cmd_check, command_check
    MATCH cmd_about, command_about
    MATCH cmd_version, command_version
    MATCH cmd_reset, command_reset
    MATCH cmd_clear, command_clear
    MATCH cmd_shutdown, command_shutdown
    PRINT unknown_text
    mov eax, 1
    ret

command_help:
    call show_help
    mov eax, 1
    ret
command_status:
    call show_status
    mov eax, 1
    ret
command_memory:
    call show_memory
    mov eax, 1
    ret
command_process:
    call show_processes
    mov eax, 1
    ret
command_start:
    mov dword [rel system_running], 1
    PRINT started_text
    mov eax, 1
    ret
command_stop:
    mov dword [rel system_running], 0
    PRINT stopped_text
    mov eax, 1
    ret
command_cpu:
    call show_cpu
    mov eax, 1
    ret
command_disk:
    call show_disk
    mov eax, 1
    ret
command_check:
    call show_check
    mov eax, 1
    ret
command_about:
    call show_about
    mov eax, 1
    ret
command_version:
    PRINT version_text
    mov eax, 1
    ret
command_reset:
    mov dword [rel system_running], 1
    PRINT reset_text
    mov eax, 1
    ret
command_clear:
    PRINT clear_code
    mov eax, 1
    ret
command_shutdown:
    PRINT shutdown_text
    xor eax, eax
    ret

show_help:
    PRINT help_text
    ret
show_status:
    PRINT status_title
    cmp dword [rel system_running], 1
    jne .stopped
    PRINT status_running
    ret
.stopped:
    PRINT status_stopped
    ret
show_memory:
    PRINT memory_text
    ret
show_processes:
    PRINT process_text
    ret
show_cpu:
    PRINT cpu_text
    ret
show_disk:
    PRINT disk_text
    ret
show_check:
    PRINT check_text
    ret
show_about:
    PRINT about_text
    ret

; Write a null-terminated string followed by a newline to stdout.
print_line:
    mov rdx, rsi
.count:
    cmp byte [rdx], 0
    je .write_text
    inc rdx
    jmp .count
.write_text:
    sub rdx, rsi
    mov eax, 1
    mov edi, 1
    syscall
    mov eax, 1
    mov edi, 1
    lea rsi, [rel newline]
    mov edx, 1
    syscall
    ret

; Return zero when the two null-terminated strings are equal.

compare_strings:
.compare:
    mov al, [rdi]
    mov dl, [rsi]
    cmp al, dl
    jne .different
    test al, al
    jz .equal
    inc rdi
    inc rsi
    jmp .compare
.different:
    mov eax, 1
    ret
.equal:
    xor eax, eax
    ret

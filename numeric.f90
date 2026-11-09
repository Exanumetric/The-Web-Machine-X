program the_web_machine_x_simulator
    implicit none
    integer, parameter :: max_processes = 10
    integer, parameter :: total_memory = 16384
    integer, parameter :: memory_per_process = 128
    character(len=32) :: processes(max_processes)
    character(len=40) :: command
    integer :: process_count
    integer :: memory_used
    integer :: next_process_id
    integer :: commands_run
    integer :: input_status
    logical :: running
    call initialize_system()
    call show_banner()
    running = .true.
    do while (running)
        write(*,'(A)', advance='no') 'WMX> '
        command = 'SHUTDOWN'
        if (input_status /= 0) then
            print *, 'No more input; shutting down.'
            exit
        end if
        call uppercase(command)
        if (len_trim(command) == 0) cycle
        commands_run = commands_run + 1
        select case (trim(command))
        case ('HELP')
            call show_help()
        case ('STATUS')
            call show_status()
        case ('MEMORY')
            call show_memory()
        case ('PROCESS')
            call list_processes()
        case ('START')
            call start_process()
        case ('STOP')
            call stop_process()
        case ('CPU')
            call show_cpu()
        case ('DISK')
            call show_disk()
        case ('CHECK')
            call system_check()
        case ('ABOUT')
            call show_about()
        case ('VERSION')
            call show_version()
        case ('RESET')
            call reset_simulator()
        case ('CLEAR')
            call clear_screen()
        case ('SHUTDOWN')
            running = .false.
            print *, 'Shutting down...'
        case default
            print *, 'Unknown command.'
            print *, 'Type HELP for commands.'
        end select
    end do
    print *, 'Commands processed: ', commands_run
    print *, 'Simulator terminated.'
contains

    subroutine initialize_system()
        process_count = 0
        memory_used = 2048
        next_process_id = 1
        commands_run = 0
        processes = ''
    end subroutine initialize_system
    subroutine show_banner()
        print *, '========================================'
        print *, '          THE WEB MACHINE X'
        print *, '             VERSION 0.0.2'
        print *, '          SECOND PRE-RELEASE'
        print *, '========================================'
        print *, 'Architecture: SIMULATED'
        print *, 'Runtime: FORTRAN'
        print *, 'Type HELP for commands.'
    end subroutine show_banner
    subroutine show_help()
        print *, 'AVAILABLE COMMANDS'
        print *, 'HELP      Show command list'
        print *, 'STATUS    Show system status'
        print *, 'MEMORY    Show memory information'
        print *, 'PROCESS   List active processes'
        print *, 'START     Start a simulated process'
        print *, 'STOP      Stop the latest process'
        print *, 'CPU       Show simulated processor'
        print *, 'DISK      Show simulated disk'
        print *, 'CHECK     Run system diagnostics'
        print *, 'ABOUT     Show project information'
        print *, 'VERSION   Show release information'
        print *, 'RESET     Reset simulator state'
        print *, 'CLEAR     Clear terminal display'
        print *, 'SHUTDOWN  Exit the simulator'
    end subroutine show_help
    subroutine show_status()
        print *, 'SYSTEM STATUS'
        print *, 'State: OPERATIONAL'
        print *, 'Version: 0.0.2'
        print *, 'Release: SECOND PRE-RELEASE'
        print *, 'Processes: ', process_count
        print *, 'Memory used: ', memory_used, ' MB'
        print *, 'Memory free: ', total_memory - memory_used, ' MB'
        print *, 'Commands: ', commands_run
    end subroutine show_status
    subroutine show_memory()
        integer :: free_memory
        real :: percentage
        free_memory = total_memory - memory_used
        percentage = 100.0 * real(memory_used) / real(total_memory)
        print *, 'MEMORY REPORT'
        print *, 'Total: ', total_memory, ' MB'
        print *, 'Used:  ', memory_used, ' MB'
        print *, 'Free:  ', free_memory, ' MB'
        print '(A,F6.2,A)', 'Usage: ', percentage, '%'
    end subroutine show_memory
    subroutine list_processes()
        integer :: i
        print *, 'PROCESS TABLE'
        if (process_count == 0) then
            print *, 'No active processes.'
            return
        end if
        do i = 1, process_count
            print '(I2,2X,A)', i, trim(processes(i))
        end do
        print *, 'Total: ', process_count
    end subroutine list_processes
    subroutine start_process()
        character(len=32) :: process_name
        if (process_count >= max_processes) then
            print *, 'Process limit reached.'
            return
        end if
        if (memory_used + memory_per_process > total_memory) then
            print *, 'Insufficient simulated memory.'
            return
        end if
        write(process_name, '(A,I0)') 'PROCESS_', next_process_id
        process_count = process_count + 1
        processes(process_count) = process_name
        next_process_id = next_process_id + 1
        memory_used = memory_used + memory_per_process
        print *, 'Started: ', trim(process_name)
    end subroutine start_process
    subroutine stop_process()
        if (process_count == 0) then
            print *, 'No active processes.'
            return
        end if
        print *, 'Stopping: ', trim(processes(process_count))
        processes(process_count) = ''
        process_count = process_count - 1
        memory_used = memory_used - memory_per_process
        print *, 'Process stopped.'
    end subroutine stop_process
    subroutine show_cpu()
        print *, 'SIMULATED PROCESSOR'
        print *, 'Name: WMX Virtual CPU'
        print *, 'Architecture: SIMULATED'
        print *, 'Cores: 4'
        print *, 'Frequency: 2400 MHz'
        print *, 'Status: READY'
    end subroutine show_cpu
    subroutine show_disk()
        print *, 'SIMULATED STORAGE'
        print *, 'Device: WMX-DISK-0'
        print *, 'Capacity: 256 GB'
        print *, 'Used: 32 GB'
        print *, 'Free: 224 GB'
        print *, 'Status: READY'
    end subroutine show_disk
    subroutine system_check()
        logical :: memory_ok
        logical :: process_ok
        memory_ok = memory_used >= 0 .and. memory_used <= total_memory
        process_ok = process_count >= 0 .and. process_count <= max_processes
        print *, 'SYSTEM DIAGNOSTICS'
        if (memory_ok) then
            print *, 'Memory check: PASS'
        else
            print *, 'Memory check: FAIL'
        end if
        if (process_ok) then
            print *, 'Process check: PASS'
        else
            print *, 'Process check: FAIL'
        end if
        print *, 'Simulator check: PASS'
    end subroutine system_check
    subroutine show_about()
        print *, 'THE WEB MACHINE X'
        print *, 'System simulator'
        print *, 'Version: 0.0.2'
        print *, 'Second pre-release'
        print *, 'Language: Fortran'
        print *, 'Purpose: Educational simulation'
        print *, 'Real hardware access: None'
    end subroutine show_about
    subroutine show_version()
        print *, '================================'
        print *, 'The Web Machine X'
        print *, 'Version 0.0.2'
        print *, 'Second pre-release'
        print *, 'Release date: November 8, 2026'
        print *, '================================'
    end subroutine show_version
    subroutine reset_simulator()
        process_count = 0
        memory_used = 2048
        processes = ''
        print *, 'Simulator state reset.'
        print *, 'Next process ID: ', next_process_id
    end subroutine reset_simulator
    subroutine clear_screen()
        integer :: i
        do i = 1, 30
            print *, ' '
        end do
    end subroutine clear_screen
    subroutine uppercase(text)
        character(len=*), intent(inout) :: text
        integer :: i
        integer :: code
        do i = 1, len_trim(text)
            code = iachar(text(i:i))
            if (code >= iachar('a') .and. code <= iachar('z')) then
                text(i:i) = achar(code - 32)
            end if
        end do
    end subroutine uppercase
end program the_web_machine_x_simulator

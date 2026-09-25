program system_command
    implicit none
    integer :: exit_status
    
    print *, "Welcome to The Web Machine X System!"

    call execute_command_line("mkdir -p system", exitstat=exit_status)

    if (exit_status == 0) then
        print *, "Ver: 0.01"
    else
        print *, "System Failed Error: 6110xb2", exit_status
    end if
end program system_command

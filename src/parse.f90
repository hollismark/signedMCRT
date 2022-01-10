module parse_mod

    use tomlf
    use constants, only : wp

    implicit none

    private
    public :: parse_params

    contains

    subroutine parse_params(filename, dict)
    
        use dict_mod

        implicit none
    
        character(*), intent(IN)    :: filename
        type(dict_t), intent(INOUT) :: dict
        
        type(toml_table), allocatable :: table

        integer :: u

        open(newunit=u, file=trim(filename))
        call toml_parse(table, u)
        
        call parse_source(table, dict)
        call parse_grid(table)
        call parse_geometry(table, dict)
        call parse_output(table)
        call parse_simulation(table)

    end subroutine parse_params
    
    subroutine parse_source(table, dict)

        use dict_mod
        use sim_state_mod, only : state

        implicit none
        
        type(toml_table), intent(INOUT) :: table
        type(dict_t),     intent(INOUT) :: dict

        type(toml_table), pointer :: child
        type(toml_array), pointer :: children

        real(kind=wp) :: dir(3), pos(3)
        integer :: i, nlen
        character(len=1) :: axis(3)

        axis = ["x", "y", "z"]

        call get_value(table, "source", child)

        if(associated(child))then
            call get_value(child, "name", state%source, "point")
            call get_value(child, "nphotons", state%nphotons, 1000000)

            call get_value(child, "position", children, requested=.false.)
            if(associated(children))then
                nlen = len(children)
                if(nlen < 3)then
                    error stop "Need a vector of size 3 for position."
                end if
                do i = 1, len(children)
                    call get_value(children, i, pos(i))
                    call dict%add_entry("pos%"//axis(i), pos(i))
                end do
            end if

            children => null()
            
            call get_value(child, "direction", children, requested=.false.)
            if(associated(children))then
                nlen = len(children)
                if(nlen < 3)then
                    error stop "Need a vector of size 3 for direction."
                end if
                do i = 1, len(children)
                    call get_value(children, i, dir(i))
                    call dict%add_entry("dir%"//axis(i), dir(i))
                end do
            end if
        else
            error stop "Need source table in input param file"
        end if

    end subroutine parse_source

    subroutine parse_grid(table)

        use sim_state_mod, only : state
        use gridMod,       only : init_grid 

        implicit none
        
        type(toml_table), intent(INOUT) :: table

        type(toml_table), pointer :: child
        integer                   :: nxg, nyg, nzg
        real(kind=wp)             :: xmax, ymax, zmax

        call get_value(table, "grid", child)

        if(associated(child))then
            call get_value(child, "nxg", nxg, 200)
            call get_value(child, "nyg", nyg, 200)
            call get_value(child, "nzg", nzg, 200)
            call get_value(child, "xmax", xmax, 1.0_wp)
            call get_value(child, "ymax", ymax, 1.0_wp)
            call get_value(child, "zmax", zmax, 1.0_wp)
        else
            error stop "Need grid table in input param file"
        end if

        state%grid = init_grid(nxg, nyg, nzg, xmax, ymax, zmax)

    end subroutine parse_grid

    subroutine parse_geometry(table, dict)

        use dict_mod
        use sim_state_mod, only : state
        
        implicit none
        
        type(toml_table), intent(INOUT) :: table
        type(dict_t),     intent(IN)    :: dict
        
        type(toml_table), pointer :: child
        real(kind=wp)             :: tau

        call get_value(table, "geometry", child)

        if(associated(child))then
            call get_value(child, "geom_name", state%experiment, "sphere")
            call get_value(child, "tau", tau, 10._wp)
            call dict%add_entry("tau", tau)
        else
            error stop "Need geometry table in input param file"
        end if

    end subroutine parse_geometry

    subroutine parse_output(table)

        use sim_state_mod, only : state

        implicit none
        
        type(toml_table), intent(INOUT) :: table

        type(toml_table), pointer :: child

        call get_value(table, "output", child)

        if(associated(child))then
            call get_value(child, "fluence", state%outfile, "fluence.nrrd")
            call get_value(child, "render", state%renderfile, "geom_render.nrrd")
            call get_value(child, "render_geom", state%render_geom, .false.)
        else
            error stop "Need output table in input param file"
        end if

    end subroutine parse_output

    subroutine parse_simulation(table)

        use sim_state_mod, only : state

        implicit none
        
        type(toml_table), intent(INOUT) :: table

        type(toml_table), pointer :: child

        call get_value(table, "simulation", child)

        if(associated(child))then
            call get_value(child, "seed", state%iseed, 123456789)
        else
            error stop "Need simulation table in input param file"
        end if

    end subroutine parse_simulation
end module parse_mod
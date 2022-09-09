module parse_mod

    use tomlf
    use constants, only : wp

    implicit none

    private
    public :: parse_params

    contains

    subroutine parse_params(filename, packet, dects, dict)
    
        use fhash, only : fhash_tbl_t
        use photonmod
        use detector_mod, only : dect_array

        implicit none
    
        character(*),      intent(IN)    :: filename
        type(fhash_tbl_t), intent(INOUT) :: dict
        type(photon),      intent(OUT)   :: packet
        type(dect_array), allocatable, intent(out) :: dects(:)

        type(toml_table), allocatable :: table
        type(toml_context) :: context
        type(toml_error), allocatable :: error

        call toml_load(table, trim(filename), context=context, error=error)
        if(allocated(error))then
            print'(a)',error%message
            stop 1
        end if

        call parse_source(table, packet, dict, context)
        call parse_grid(table, dict)
        call parse_geometry(table, dict)
        call parse_detectors(table, dects, context)
        call parse_output(table, dict)
        call parse_simulation(table)

    end subroutine parse_params
    
    subroutine parse_detectors(table, dects, context)

        use detector_mod

        type(toml_table) :: table
        type(dect_array), allocatable :: dects(:)
        type(toml_context), intent(in) :: context

        type(toml_array), pointer :: array
        type(toml_table), pointer :: child
        character(len=:), allocatable :: dect_type
        type(circle_dect), target, save, allocatable :: dect_c(:)
        type(annulus_dect), target, save, allocatable :: dect_a(:)
        real(kind=wp) :: value 
        integer :: i, c_counter, a_counter, j, origin

        c_counter = 0
        a_counter = 0
        call get_value(table, "detectors", array)
        allocate(dects(len(array)))

        do i = 1, len(array)
            call get_value(array, i, child)
            call get_value(child, "type", dect_type, origin=origin)
            select case(dect_type)
            case default
                print'(a)',context%report("Invalid detector type. Valid types are [circle, annulus]", origin, "expected valid detector type")
                stop 1
            case("circle")
                c_counter = c_counter + 1
            case("annulus")
                a_counter = a_counter + 1
            end select
        end do

        if(c_counter > 0)allocate(dect_c(c_counter))
        if(a_counter > 0)allocate(dect_a(a_counter))
        c_counter = 1
        a_counter = 1
        do i = 1, len(array)
            call get_value(array, i, child)
            call get_value(child, "type", dect_type)
            select case(dect_type)
            case("circle")
                call handle_circle_dect(child, dect_c, c_counter)
            case("annulus")
                call handle_annulus_dect(child, dect_a, a_counter, context)
            end select
        end do

        do i = 1, c_counter-1
            allocate(dects(i)%p, source=dect_c(i))
            dects(i)%p => dect_c(i)
        end do

        do j = 1, a_counter-1
            allocate(dects(j+i-1)%p, source=dect_a(j))
            dects(j+i-1)%p => dect_a(j)
        end do

    end subroutine parse_detectors


    subroutine handle_circle_dect(child, dects, counts)

        use detector_mod

        type(toml_table), pointer, intent(in)    :: child
        type(circle_dect),         intent(inout) :: dects(:)
        integer,                   intent(inout) :: counts

        integer :: layer, nbins, j
        real(kind=wp) :: maxval, radius
        real(kind=wp), allocatable :: tmp(:)
        type(toml_array), pointer  :: arr
        type(vector) :: pos

        call get_value(child, "position", arr)
        if (associated(arr))then
            allocate(tmp(len(arr)))
            do j = 1, len(arr)
                call get_value(arr, j, tmp(j))
            end do
            pos = vector(tmp(1), tmp(2), tmp(3))
            end if
        call get_value(child, "layer", layer, 1)
        call get_value(child, "radius", radius)
        call get_value(child, "nbins", nbins, 100)
        call get_value(child, "maxval", maxval, 100._wp)
        dects(counts) = circle_dect(pos, layer, radius, nbins, maxval)
        counts = counts + 1

    end subroutine handle_circle_dect

    subroutine handle_annulus_dect(child, dects, counts, context)

        use detector_mod

        type(toml_table), pointer, intent(in)    :: child
        type(annulus_dect),        intent(inout) :: dects(:)
        integer,                   intent(inout) :: counts
        type(toml_context),        intent(in) :: context

        integer :: layer, nbins, j, origin
        real(kind=wp) :: maxval, radius1, radius2
        real(kind=wp), allocatable :: tmp(:)
        type(toml_array), pointer  :: arr
        type(vector) :: pos

        call get_value(child, "position", arr)
        if (associated(arr))then
            allocate(tmp(len(arr)))
            do j = 1, len(arr)
                call get_value(arr, j, tmp(j))
            end do
            pos = vector(tmp(1), tmp(2), tmp(3))
            end if
        call get_value(child, "layer", layer, 1)
        call get_value(child, "radius1", radius1)
        call get_value(child, "radius2", radius2, origin=origin)
        if(radius2 <= radius1)then
            print'(a)',context%report("Radii are invalid", origin, "Expected radius2 > radius 1")
            stop 1
        end if
            call get_value(child, "nbins", nbins, 100)
        call get_value(child, "maxval", maxval, 100._wp)
        dects(counts) = annulus_dect(pos, layer, radius1, radius2, nbins, maxval)
        counts = counts + 1
    end subroutine handle_annulus_dect

    subroutine parse_source(table, packet, dict, context)

        use fhash, only : fhash_tbl_t, key=>fhash_key
        use sim_state_mod, only : state
        use photonmod

        implicit none
        
        type(toml_table),  intent(INOUT) :: table
        type(fhash_tbl_t), intent(INOUT) :: dict
        type(photon),      intent(OUT)   :: packet
        type(toml_context) :: context

        type(toml_table), pointer :: child
        type(toml_array), pointer :: children

        real(kind=wp) :: dir(3), pos(3), corners(3, 3), radius
        integer :: i, nlen, origin
        character(len=1) :: axis(3)
        character(len=:), allocatable :: direction

        axis = ["x", "y", "z"]
        pos = 0._wp
        dir = 0._wp
        corners = reshape((/ -1._wp, -1._wp, 1._wp, &
                              2._wp,  0._wp, 0._wp, &
                              0._wp,  2._wp, 0._wp /), &
                           shape(corners), order=[2, 1])

        call get_value(table, "source", child, requested=.false.)
        if(associated(child))then
            call get_value(child, "name", state%source, "point")
            call get_value(child, "nphotons", state%nphotons, 1000000)

            call get_value(child, "position", children, requested=.false., origin=origin)
            if(associated(children))then
                nlen = len(children)
                if(nlen < 3)then
                    print'(a)',context%report("Need a vector of size 3 for position", origin, "expected vector of size 3")
                    stop 1
                end if
                do i = 1, len(children)
                    call get_value(children, i, pos(i))
                    call dict%set(key("pos%"//axis(i)), value=pos(i))
                end do
            else
                if(state%source == "point")then
                    pos = [0._wp, 0._wp, 0._wp]
                    call dict%set(key("pos%x"), value=pos(1))
                    call dict%set(key("pos%y"), value=pos(2))
                    call dict%set(key("pos%z"), value=pos(3))
                end if
            end if

            children => null()
            
            call get_value(child, "direction", children, requested=.false., origin=origin)
            if(associated(children))then
                nlen = len(children)
                if(nlen < 3)then
                    print'(a)',context%report("Need a vector of size 3 for direction", origin, "expected vector of size 3")
                    stop 1
                end if
                if(state%source == "circular")then
                    print'(a)',context%report("Direction not yet fully implmented for source type Circular. Results may not be accurate!", origin, level=toml_level%warning)
                end if
                do i = 1, len(children)
                    call get_value(children, i, dir(i))
                    call dict%set(key("dir%"//axis(i)), value=dir(i))
                end do
            else
                if(state%source == "uniform")then
                    print'(a)',context%report("Uniform source needs vector direction", origin, "expected vector of size 3")
                    stop 1
                end if
                    call get_value(child, "direction", direction, "-z")
                call dict%set(key("dir"), value=direction)
            end if

            children => null()
            
            call get_value(child, "point1", children, requested=.false., origin=origin)
            if(associated(children))then
                nlen = len(children)
                if(nlen < 3)then
                    print'(a)',context%report("Need a matrix row for points", origin, "expected matrix row of size 3")
                    stop 1
                end if
                do i = 1, len(children)
                    call get_value(children, i, corners(i, 1))
                    call dict%set(key("pos1%"//axis(i)), value=corners(i,1))
                end do
            else
                if(state%source == "uniform")then
                    print'(a)',context%report("Uniform source requires point1 variable", origin, "expected point1 variable")
                    stop 1
                end if
            end if

            call get_value(child, "point2", children, requested=.false., origin=origin)
            if(associated(children))then
                nlen = len(children)
                if(nlen < 3)then
                    print'(a)',context%report("Need a matrix row for points", origin, "expected matrix row of size 3")
                    stop 1
                end if
                do i = 1, len(children)
                    call get_value(children, i, corners(i, 2))
                    call dict%set(key("pos2%"//axis(i)), value=corners(i,2))
                end do
            else
                if(state%source == "uniform")then
                    print'(a)',context%report("Uniform source requires point2 variable", origin, "expected point2 variable")
                    stop 1
                end if
            end if

            call get_value(child, "point3", children, requested=.false., origin=origin)
            if(associated(children))then
                nlen = len(children)
                if(nlen < 3)then
                    print'(a)',context%report("Need a matrix row for points", origin, "expected matrix row of size 3")
                    stop 1
                end if
                do i = 1, len(children)
                    call get_value(children, i, corners(i, 3))
                    call dict%set(key("pos3%"//axis(i)), value=corners(i,3))
                end do
            else
                if(state%source == "uniform")then
                    print'(a)',context%report("Uniform source requires point3 variable", origin, "expected point3 variable")
                    stop 1
                end if
            end if
            call get_value(child, "radius", radius)
            call dict%set(key("radius"), value=radius)

        else
            print'(a)',context%report("Simulation needs Source table", origin, "Missing source table")
            stop 1
        end if

        packet = photon(state%source)

    end subroutine parse_source

    subroutine parse_grid(table, dict)

        use sim_state_mod, only : state
        use gridMod,       only : init_grid 
        use fhash,         only : fhash_tbl_t, key=>fhash_key

        implicit none
        
        type(toml_table),  intent(INOUT) :: table
        type(fhash_tbl_t), intent(INOUT) :: dict

        type(toml_table), pointer     :: child
        integer                       :: nxg, nyg, nzg
        real(kind=wp)                 :: xmax, ymax, zmax
        character(len=:), allocatable :: units

        call get_value(table, "grid", child)

        if(associated(child))then
            call get_value(child, "nxg", nxg, 200)
            call get_value(child, "nyg", nyg, 200)
            call get_value(child, "nzg", nzg, 200)
            call get_value(child, "xmax", xmax, 1.0_wp)
            call get_value(child, "ymax", ymax, 1.0_wp)
            call get_value(child, "zmax", zmax, 1.0_wp)
            call get_value(child, "units", units, "cm")
            call dict%set(key("units"), value=units)
        else
            error stop "Need grid table in input param file"
        end if

        state%grid = init_grid(nxg, nyg, nzg, xmax, ymax, zmax)

    end subroutine parse_grid

    subroutine parse_geometry(table, dict)

        use fhash,         only : fhash_tbl_t, key=>fhash_key
        use sim_state_mod, only : state
        
        implicit none
        
        type(toml_table),  intent(INOUT) :: table
        type(fhash_tbl_t), intent(INOUT) :: dict
        
        type(toml_table), pointer :: child
        real(kind=wp)             :: tau, musb, musc, muab, muac, hgg
        integer                   :: num_spheres

        call get_value(table, "geometry", child)

        if(associated(child))then
            call get_value(child, "geom_name", state%experiment, "sphere")
            call get_value(child, "tau", tau, 10._wp)
            call dict%set(key("tau"), value=tau)

            call get_value(child, "num_spheres", num_spheres, 10)
            call dict%set(key("num_spheres"), value=num_spheres)

            call get_value(child, "musb", musb, 0.0_wp)
            call dict%set(key("musb"), value=musb)
            call get_value(child, "muab", muab, 0.01_wp)
            call dict%set(key("muab"), value=muab)
            call get_value(child, "musc", musc, 0.0_wp)
            call dict%set(key("musc"), value=musc)
            call get_value(child, "muac", muac, 0.01_wp)
            call dict%set(key("muac"), value=muac)
            call get_value(child, "hgg", hgg, 0.7_wp)
            call dict%set(key("hgg"), value=hgg)
        else
            error stop "Need geometry table in input param file"
        end if

    end subroutine parse_geometry

    subroutine parse_output(table, dict)

        use sim_state_mod, only : state
        use fhash,         only : fhash_tbl_t, key=>fhash_key

        implicit none
        
        type(toml_table),  intent(INOUT) :: table
        type(fhash_tbl_t), intent(INOUT) :: dict

        type(toml_table), pointer :: child
        type(toml_array), pointer :: children
        logical :: overwrite
        integer :: i, nlen

        call get_value(table, "output", child)

        if(associated(child))then
            call get_value(child, "fluence", state%outfile, "fluence.nrrd")
            call get_value(child, "render", state%renderfile, "geom_render.nrrd")
            call get_value(child, "render_geom", state%render_geom, .false.)
            

            call get_value(child, "render_size", children, requested=.false.)
            if(associated(children))then
                nlen = len(children)
                if(nlen < 3)then
                    error stop "Need a vector of size 3 for render_size."
                end if
                do i = 1, len(children)
                    call get_value(children, i, state%render_size(i))
                end do
            else
                state%render_size = [200, 200, 200]
            end if

            call get_value(child, "overwrite", overwrite, .false.)
            call dict%set(key("overwrite"), value=overwrite)
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
            call get_value(child, "tev", state%tev, .false.)

        else
            error stop "Need simulation table in input param file"
        end if

    end subroutine parse_simulation
end module parse_mod

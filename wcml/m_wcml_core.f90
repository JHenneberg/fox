module m_wcml_core

  use FoX_common, only: FoX_version
  use m_common_error, only: FoX_error
  use m_common_format, only: str
  use FoX_wxml, only: xmlf_t
  use FoX_wxml, only: xml_NewElement, xml_AddCharacters, xml_AddAttribute
  use FoX_wxml, only: xml_EndElement, xml_AddNamespace
  use m_wcml_stml, only: stmAddValue

  implicit none
  private

  integer, parameter ::  sp = selected_real_kind(6,30)
  integer, parameter ::  dp = selected_real_kind(14,100)
  character(len=*), parameter :: spformat = '(es11.3)'
  character(len=*), parameter :: dpformat = '(es16.8)'
  
! CMLUnits
  character(len=*), parameter :: U_ANGSTR = 'units:angstrom'
  character(len=*), parameter :: U_DEGREE = 'units:degree'
  character(len=*), parameter :: U_RADIAN = 'units:radian'

  public :: cmlStartCml
  public :: cmlEndCml

! CMLCore
  public :: cmlAddCoordinates
  public :: cmlAddCrystal
  public :: cmlAddEigenvalue
  public :: cmlAddMolecule
  public :: cmlStartModule
  public :: cmlEndModule

  public :: cmlStartStep
  public :: cmlEndStep

! CMLCore
  interface cmlAddCoordinates
     module procedure cmlAddCoordinatesSP
     module procedure cmlAddCoordinatesDP
  end interface

  interface cmlAddCrystal
     module procedure cmlAddCrystalSP
     module procedure cmlAddCrystalDP
  end interface

  interface cmlAddEigenvalue
     module procedure cmlAddEigenvalueSP
     module procedure cmlAddEigenvalueDP
  end interface

  interface cmlAddMolecule
     module procedure cmlAddMoleculeSP
     module procedure cmlAddMoleculeDP
     module procedure cmlAddMolecule3SP
     module procedure cmlAddMolecule3DP
  end interface

contains

  ! =================================================
  ! convenience CML routines
  ! =================================================

! Open and close a CML document.

  subroutine cmlStartCml(xf, id, title, conv, dictref, ref)
    type(xmlf_t), intent(inout) :: xf

    character(len=*), intent(in), optional :: id
    character(len=*), intent(in), optional :: title
    character(len=*), intent(in), optional :: conv
    character(len=*), intent(in), optional :: dictref
    character(len=*), intent(in), optional :: ref

    call xml_AddNamespace(xf, 'http://www.xml-cml.org/schema')
    call xml_AddNamespace(xf, 'http://www.w3.org/2001/XMLSchema', 'xsd')
    call xml_AddNamespace(xf, 'http://purl.org/dc/elements/1.1/title', 'dc')
! FIXME TOHW we will want other namespaces in here - particularly for units
! once PMR has stabilized that.

    call xml_NewElement(xf, 'cml')
    if (present(id)) call xml_AddAttribute(xf, 'id', id)
    if (present(title)) call xml_AddAttribute(xf, 'title', title)
    if (present(dictref)) call xml_AddAttribute(xf, 'dictRef', dictref)
    if (present(conv)) call xml_AddAttribute(xf, 'convention', conv)
    if (present(ref)) call xml_AddAttribute(xf, 'ref', ref)

  end subroutine cmlStartCml

  subroutine cmlEndCml(xf)
    type(xmlf_t), intent(inout) :: xf

  !  call cmlAddMetadata(xf, name='dc:contributor', content='FoX-'//FoX_version//' (http://www.eminerals.org)')
    call xml_EndElement(xf, 'cml')

  end subroutine cmlEndCml

  ! -------------------------------------------------
  ! writes a Module start/end Tag to xml channel
  ! -------------------------------------------------
  subroutine cmlStartModule(xf, id, title, conv, dictref, ref, role, serial)

    type(xmlf_t), intent(inout) :: xf
    character(len=*), intent(in), optional :: id
    character(len=*), intent(in), optional :: title
    character(len=*), intent(in), optional :: conv
    character(len=*), intent(in), optional :: dictref
    character(len=*), intent(in), optional :: ref
    character(len=*), intent(in), optional :: role
    character(len=*), intent(in), optional :: serial
    
    call xml_NewElement(xf, 'module')
    if (present(id)) call xml_AddAttribute(xf, 'id', id)
    if (present(title)) call xml_AddAttribute(xf, 'title', title)
    if (present(dictref)) call xml_AddAttribute(xf, 'dictRef', dictref)
    if (present(conv)) call xml_AddAttribute(xf, 'convention', conv)
    if (present(ref)) call xml_AddAttribute(xf, 'ref', ref)
    if (present(role)) call xml_AddAttribute(xf, 'role', role)
    if (present(serial)) call xml_AddAttribute(xf, 'serial', serial)
    
  end subroutine cmlStartModule

  subroutine cmlEndModule(xf)

    type(xmlf_t), intent(inout) :: xf

    Call xml_EndElement(xf, 'module')
    
  end subroutine cmlEndModule

  ! -------------------------------------------------
  ! writes a step start Tag to xml channel
  ! -------------------------------------------------

  subroutine cmlStartStep(xf, type, index, id, title, conv, ref)

    type(xmlf_t), intent(inout) :: xf
    character(len=*), intent(in), optional :: type
    character(len=*), intent(in), optional :: id
    integer, intent(in), optional :: index
    character(len=*), intent(in), optional :: title
    character(len=*), intent(in), optional :: conv
    character(len=*), intent(in), optional :: ref

    if (present(index)) then
      call cmlStartModule(xf=xf, id=id, title=title, conv=conv, dictRef=type, ref=ref, role='step', serial=str(index))
    else
      call cmlStartModule(xf=xf, id=id, title=title, conv=conv, dictRef=type, ref=ref, role='step')
    endif
    
  end subroutine cmlStartStep

  subroutine cmlEndStep(xf)

    type(xmlf_t), intent(inout) :: xf

    Call xml_EndElement(xf, 'module')
    
  end subroutine cmlEndStep

  ! -------------------------------------------------
  ! 1. writes complete DP molecule to xml channel
  ! -------------------------------------------------

  subroutine cmlAddMoleculeDP(xf, natoms, elements, refs, coords, occupancies, style, id, title, dictref, fmt)

    type(xmlf_t), intent(inout) :: xf
    integer, intent(in)                    :: natoms             ! number of atoms
    real(kind=dp), intent(in)              :: coords(3, natoms)  ! atomic coordinates
    character(len=*), intent(in)           :: elements(natoms)   ! chemical element types
    character(len=*), intent(in), optional :: refs(natoms) 
    real(kind=dp), intent(in), optional :: occupancies(natoms) 
    character(len=*), intent(in), optional :: id                 ! id
    character(len=*), intent(in), optional :: title              ! the title
    character(len=*), intent(in), optional :: dictref            ! the dictionary reference
    character(len=*), intent(in), optional :: fmt                ! format for coords
    character(len=*), intent(in), optional :: style              ! type of coordinates 

    ! 'x3' for Cartesians, 
    ! 'xFrac' for fractionals
    ! default => cartesians

    ! Internal Variables
    !character(len=6) :: id1, id0
    character(len=20):: stylei
    integer          :: i

    if (present(style)) then
      stylei = style
    else
      stylei = 'x3'
    endif
    
    call xml_NewElement(xf, 'molecule')
    if (present(id)) call xml_AddAttribute(xf, 'id', id)
    if (present(title)) call xml_AddAttribute(xf, 'id', title)
    if (present(dictRef)) call xml_AddAttribute(xf, 'dictRef', dictRef)
    call xml_NewElement(xf, 'atomArray')
    !TOHW this should be cleaned up .... Internal writes should go through str
    do i = 1, natoms
      ! This next is obviously bollocks. It will result in duplicate ids.
      !write(id0, '(i4)') i
      !id0 = adjustl(id0)
      !id1 = 'a'
      !id1(2:) = id0
      !call cmlAddAtom(xf=xf, elem=elements(i), id=trim(id1))
      ! There is a case to be made for TRIMing the elements(i) and refs(i) strings
      ! because they are part of an array, and the user cannot pass in strings
      ! of varying length.
      if (present(occupancies)) then
        call cmlAddAtom(xf=xf, elem=trim(elements(i)), &
          occupancyDP=occupancies(i))
      else
        call cmlAddAtom(xf=xf, elem=trim(elements(i)))
      endif
        if (present(refs)) call xml_AddAttribute(xf, 'ref', refs(i))
        if (stylei .eq. 'x3') then
          call CMLATX39DP(xf, coords(1, i), coords(2, i), coords(3, i), fmt)
        elseif (stylei .eq. 'xFrac') then
          call CMLATXF9DP(xf, coords(1, i), coords(2, i), coords(3, i), fmt)
        elseif (stylei .eq. 'xyz3') then
          call CMLATXYZ39DP(xf, coords(1, i), coords (2, i), coords(3, i), fmt)
        elseif (stylei .eq. 'xyzFrac') then
          call CMLATXYZFRACT9DP(xf, coords(1, i), coords(2, i), coords(3, i), fmt)
        endif
       call xml_EndElement(xf, 'atom')
    enddo

    call xml_EndElement(xf, 'atomArray')
    call xml_EndElement(xf, 'molecule')
    
  end subroutine cmlAddMoleculeDP

  
  ! -------------------------------------------------
  ! 2. writes complete SP molecule to xml channel
  ! -------------------------------------------------
  
  subroutine cmlAddMoleculeSP(xf, natoms, elements, refs, coords, occupancies, style, id, title, dictref, fmt)
    type(xmlf_t), intent(inout) :: xf
    integer, intent(in)                    :: natoms          ! number of atoms
    character(len=*), intent(in)           :: elements(*)     ! chemical element types
    real(kind=sp), intent(in)              :: coords(3, *)    ! atomic coordinates
    character(len=*), intent(in), optional :: refs(natoms)    ! id
    real(kind=sp), intent(in), optional :: occupancies(natoms) 
    character(len=*), intent(in), optional :: id              ! id
    character(len=*), intent(in), optional :: title           ! the title
    character(len=*), intent(in), optional :: dictref         ! the dictionary reference
    character(len=*), intent(in), optional :: fmt             ! format for coords
    character(len=*), intent(in), optional :: style           ! type of coordinates ('x3'for Cartesians, 'xFrac' 
    ! for fractionals; ' ' = default => cartesians)
    ! Flush on entry and exit
    !character(len=6) :: id1, id0
    integer          :: i
    character(len=10):: stylei

    if (present(style)) then
       stylei = style
    else
       stylei = 'x3'
    endif

    call xml_NewElement(xf, 'molecule')
    if (present(id)) call xml_AddAttribute(xf, 'id', id)
    if (present(title)) call xml_AddAttribute(xf, 'id', title)
    if (present(dictRef)) call xml_AddAttribute(xf, 'dictRef', dictRef)
    call xml_NewElement(xf, 'atomArray')
    do i = 1, natoms
       !write(id0, '(i4)') i
       !id0 = adjustl(id0)
       !id1 = 'a'
       !id1(2:) = id0
       !call cmlAddAtom(xf=xf, elem=elements(i), id=trim(id1))
      if (present(occupancies)) then
        call cmlAddAtom(xf=xf, elem=trim(elements(i)), &
          occupancySP=occupancies(i))
      else
        call cmlAddAtom(xf=xf, elem=trim(elements(i)))
      endif
       call cmlAddAtom(xf=xf, elem=trim(elements(i)))
       if (present(refs)) call xml_AddAttribute(xf, 'ref', refs(i))
       if (stylei .eq. 'x3') then
          call CMLATX39SP(xf, coords(1, i), coords(2, i), coords(3, i), fmt)
       elseif (stylei .eq. 'xFrac') then
          call CMLATXF9SP(xf, coords(1, i), coords(2, i), coords(3, i), fmt)
       elseif (stylei .eq. 'xyz3') then
          call CMLATXYZ39SP(xf, coords(1, i), coords(2, i), coords(3, i), fmt)
       elseif (stylei .eq. 'xyzFrac') then
          call CMLATXYZFRACT9SP(xf, coords(1, i), coords(2, i), coords(3, i), fmt)
       endif
       call xml_EndElement(xf, 'atom')
    enddo

    call xml_EndElement(xf, 'atomArray')
    call xml_EndElement(xf, 'molecule')
    
    
  end subroutine cmlAddMoleculeSP
  
  
  ! -------------------------------------------------
  ! 1. writes complete DP molecule to xml channel (No. 2)
  ! -------------------------------------------------
  
  subroutine cmlAddMolecule3DP(xf, natoms, elements, x, y, z, style, id, title, dictref, fmt)
    type(xmlf_t), intent(inout) :: xf
    integer, intent(in)                    :: natoms          ! number of atoms
    real(kind=dp), intent(in)               :: x(*)
    real(kind=dp), intent(in)               :: y(*)
    real(kind=dp), intent(in)               :: z(*)
    character(len=*), intent(in)           :: elements(*)     ! chemical element types
    character(len=*), intent(in), optional :: id              ! id
    character(len=*), intent(in), optional :: title           ! the title
    character(len=*), intent(in), optional :: dictref         ! the dictionary reference
    character(len=*), intent(in), optional :: fmt             ! format for coords
    character(len=*), intent(in), optional :: style           ! type of coordinates ('x3' for Cartesians, 'xFrac' 
    ! for fractionals; ' ' = default => cartesians)
    !character(len=6)  :: id1, id0
    integer           :: i
    character(len=10) :: stylei

    if (present(style)) then
       stylei = style
    else
       stylei = 'x3'
    endif

    call xml_NewElement(xf, 'molecule')
    if (present(id)) call xml_AddAttribute(xf, 'id', id)
    if (present(title)) call xml_AddAttribute(xf, 'id', title)
    if (present(dictRef)) call xml_AddAttribute(xf, 'dictRef', dictRef)
    call xml_NewElement(xf, 'atomArray')

    do i = 1, natoms
       !write(id0, '(i4)') i
       !id0 = adjustl(id0)
       !id1 = 'a'
       !id1(2:) = id0
       !call cmlAddAtom(xf=xf, elem=elements(i), id=trim(id1))
       call cmlAddAtom(xf=xf, elem=trim(elements(i)))
       if (stylei .eq. 'x3') then
          call CMLATX39DP(xf, x(i), y(i), z(i), fmt)
       elseif (stylei .eq. 'xFrac') then
          call CMLATXF9DP(xf, x(i), y(i), z(i), fmt)
       elseif (stylei .eq. 'xyz3') then
          call CMLATXYZ39DP(xf, x(i), y(i), z(i), fmt)
       elseif (stylei .eq. 'xyzFrac') then
          call CMLATXYZFRACT9DP(xf, x(i), y(i), z(i), fmt)
       endif
       call xml_EndElement(xf, 'atom')
    enddo

    call xml_EndElement(xf, 'atomArray')
    call xml_EndElement(xf, 'molecule')
    
  end subroutine cmlAddMolecule3DP
  
  
  ! -------------------------------------------------
  ! 2. writes complete SP molecule to xml channel (No. 2)
  ! -------------------------------------------------
  
  subroutine cmlAddMolecule3SP(xf, natoms, elements, x, y, z, style, id, title, dictref, fmt)


    type(xmlf_t), intent(inout) :: xf
    ! 10 Arguments
    integer, intent(in)                    :: natoms          ! number of atoms
    real(kind=sp), intent(in)               :: x(*)
    real(kind=sp), intent(in)               :: y(*)
    real(kind=sp), intent(in)               :: z(*)
    character(len=*), intent(in)           :: elements(*)      ! chemical element types
    character(len=*), intent(in), optional :: id               ! id
    character(len=*), intent(in), optional :: title            ! the title
    character(len=*), intent(in), optional :: dictref          ! the dictionary reference
    character(len=*), intent(in), optional :: fmt              ! format for coords
    character(len=*), intent(in), optional :: style            ! type of coordinates ('x3' for Cartesians, 'xFrac' 
    ! for fractionals; ' ' = default => cartesians)

    integer           :: i
    character(len=10) :: stylei

    if (present(style)) then
       stylei = style
    else
       stylei = 'x3'
    endif

    call xml_NewElement(xf, 'molecule')
    call xml_AddAttribute(xf, 'id', id)
    call xml_AddAttribute(xf, 'title', title)
    call xml_AddAttribute(xf, 'dictref', dictref)
    call xml_NewElement(xf, 'atomArray')
    do i = 1, natoms
       !write(id0, '(i4)') i
       !id0 = adjustl(id0)
       !id1 = 'a'
       !id1(2:) = id0
       !call cmlAddAtom(xf=xf, elem=elements(i), id=trim(id1))
       call cmlAddAtom(xf=xf, elem=trim(elements(i)))
       if (stylei .eq. 'x3') then
          call CMLATX39SP(xf, x(i), y(i), z(i), fmt)
       else if (stylei .eq. 'xFrac') then
          call CMLATXF9SP(xf, x(i), y(i), z(i), fmt)
       else if (stylei .eq. 'xyz3') then
          call CMLATXYZ39SP(xf, x(i), y(i), z(i), fmt)
       else if (stylei .eq. 'xyzFrac') then
          call CMLATXYZFRACT9SP(xf, x(i), y(i), z(i), fmt)
       endif
           call xml_EndElement(xf, 'atom')
    enddo

    call xml_EndElement(xf, 'atomArray')
    call xml_EndElement(xf, 'molecule')

  end subroutine cmlAddMolecule3SP
  
  ! -------------------------------------------------
  ! writes an <atom> start tag
  ! -------------------------------------------------
  
  subroutine cmlAddAtom(xf, elem, id, charge, hCount, occupancySP, occupancyDP, fmt)
    type(xmlf_t), intent(inout) :: xf
    integer, intent(in), optional           :: charge     ! formalCharge
    integer, intent(in), optional           :: hCount     ! hydrogenCount
    real(kind=sp), intent(in), optional     :: occupancySP
    real(kind=dp), intent(in), optional     :: occupancyDP
    character(len=*), intent(in), optional  :: elem       ! chemical element name
    character(len=*), intent(in), optional  :: id         ! atom id
    character(len=*), intent(in), optional  :: fmt        ! format

    call xml_NewElement(xf, 'atom')
    if (present(elem))      call xml_AddAttribute(xf, 'elementType', elem)
    if (present(id))        call xml_AddAttribute(xf, 'id', id)
    if (present(charge))    call xml_AddAttribute(xf, 'formalCharge', charge)
    if (present(hCount))    call xml_AddAttribute(xf, 'hydrogenCount', hCount)
    if (present(occupancySP) .and. present(occupancyDP)) &
      call FoX_error("Bad argumens to cmlAddAtom")
    if (present(occupancySP)) call xml_AddAttribute(xf, 'occupancy', occupancySP, fmt)
    if (present(occupancyDP)) call xml_AddAttribute(xf, 'occupancy', occupancyDP, fmt)

  end subroutine cmlAddAtom
  
  ! -------------------------------------------------
  ! 1. append SP coordinates to atom tag
  ! -------------------------------------------------
  
  subroutine cmlAddCoordinatesSP(xf, x, y, z, style, fmt)
    type(xmlf_t), intent(inout) :: xf
    real(kind=sp), intent(in)               :: x, y
    real(kind=sp), intent(in), optional     :: z
    character(len=*), intent(in), optional :: style
    character(len=*), intent(in), optional :: fmt

    ! Internal variable
    character(len=10):: stylei

    if (present(style)) then
       stylei = style
    else
       stylei = 'x3'
    endif

    if (present(z) .and. stylei .eq. 'x3') then
       call CMLATX39SP(xf, x, y, z, fmt)
    else if (present(z) .and. stylei .eq. 'xFrac') then
       call CMLATXF9SP(xf, x, y, z, fmt)
    else if (present(z) .and. stylei .eq. 'xyz3') then
       call CMLATXYZ39SP(xf, x, y, z, fmt)
    else if (present(z) .and. stylei .eq. 'xyzFrac') then
       call CMLATXYZFRACT9SP(xf, x, y, z, fmt)
    elseif (.not. present(z) .and. stylei .eq. 'xy2') then
       call CMLATXY9SP(xf, x, y, fmt)
    endif

  end subroutine cmlAddCoordinatesSP

  ! -------------------------------------------------
  ! 2. append DP coordinates to atom tag
  ! -------------------------------------------------

  subroutine cmlAddCoordinatesDP(xf, x, y, z, style, fmt)
    type(xmlf_t), intent(inout) :: xf 
    real(kind=dp), intent(in)               :: x, y
    real(kind=dp), intent(in), optional     :: z
    character(len=*), intent(in), optional :: style
    character(len=*), intent(in), optional :: fmt
    
    ! Internal variable
    character(len=10):: stylei

    if (present(style)) then
       stylei = style
    else
       stylei = 'x3'
    endif
    
    if (present(z) .and. stylei .eq. 'x3') then
       call CMLATX39DP(xf, x, y, z, fmt)
    else if (present(z) .and. stylei .eq. 'xFrac') then
       call CMLATXF9DP(xf, x, y, z, fmt)
    else if (present(z) .and. stylei .eq. 'xyz3') then
       call CMLATXYZ39DP(xf, x, y, z, fmt)
    else if (present(z) .and. stylei .eq. 'xyzFrac') then
       call CMLATXYZFRACT9DP(xf, x, y, z, fmt)
    else if (.not. present(z) .and. stylei .eq. 'xy2') then
       call CMLATXY9DP(xf, x, y, fmt)           
    endif
    
  end subroutine cmlAddCoordinatesDP


  ! -------------------------------------------------
  ! 1. creates and writes a DP <cell> element
  ! -------------------------------------------------

  subroutine cmlAddCrystalDP(xf, a, b, c, alpha, beta, gamma, id, title, dictref, conv, lenunits, angunits, spaceType, fmt)
    type(xmlf_t), intent(inout) :: xf
    real(kind=dp), intent(in)               :: a, b, c      ! cell parameters
    real(kind=dp), intent(in)               :: alpha        ! alpha cell parameter
    real(kind=dp), intent(in)               :: beta         ! beta cell parameter
    real(kind=dp), intent(in)               :: gamma        ! gamma cell parameter
    character(len=*), intent(in), optional :: id           ! id
    character(len=*), intent(in), optional :: title        ! title
    character(len=*), intent(in), optional :: dictref      ! dictref
    character(len=*), intent(in), optional :: conv         ! convention
    character(len=*), intent(in), optional :: lenunits     ! units for length (default = angstrom)
    character(len=*), intent(in), optional :: angunits     ! units for angles (default = degree)
    character(len=*), intent(in), optional :: spaceType    ! spacegroup
    character(len=*), intent(in), optional :: fmt          ! format

    ! Flush on entry and exit
    character(len=10) :: formt

    if (present(fmt)) then
       formt = fmt
    else
       formt = dpformat
    endif

    call xml_NewElement(xf=xf, name='crystal')
    if (present(id))      call xml_AddAttribute(xf, 'id', id)
    if (present(title))   call xml_AddAttribute(xf, 'title', title)
    if (present(dictref)) call xml_AddAttribute(xf, 'dictRef', dictRef)
    if (present(conv)) call xml_AddAttribute(xf, 'convention', conv)
    if (present(lenunits)) then
      call stmAddValue(xf=xf, value=a, title='a', dictref='cml:a', units=lenunits, fmt=formt)
      call stmAddValue(xf=xf, value=b, title='b', dictref='cml:b', units=lenunits, fmt=formt)
      call stmAddValue(xf=xf, value=c, title='c', dictref='cml:c', units=lenunits, fmt=formt)
    else
      call stmAddValue(xf=xf, value=a, title='a', dictref='cml:a', units=U_ANGSTR, fmt=formt)
      call stmAddValue(xf=xf, value=b, title='b', dictref='cml:b', units=U_ANGSTR, fmt=formt)
      call stmAddValue(xf=xf, value=c, title='c', dictref='cml:c', units=U_ANGSTR, fmt=formt)
    endif
    if (present(angunits)) then
      call stmAddValue(xf=xf, value=alpha, title='alpha', dictref='cml:alpha', units=angunits, fmt=formt)
      call stmAddValue(xf=xf, value=beta,  title='beta',  dictref='cml:beta',  units=angunits, fmt=formt)
      call stmAddValue(xf=xf, value=gamma, title='gamma', dictref='cml:gamma', units=angunits, fmt=formt)
    else
      call stmAddValue(xf=xf, value=alpha, title='alpha', dictref='cml:alpha', units=U_DEGREE, fmt=formt)
      call stmAddValue(xf=xf, value=beta,  title='beta',  dictref='cml:beta',  units=U_DEGREE, fmt=formt)
      call stmAddValue(xf=xf, value=gamma, title='gamma', dictref='cml:gamma', units=U_DEGREE, fmt=formt)
    endif
    if (present(spaceType)) then
      call xml_NewElement(xf, 'symmetry')
      call xml_AddAttribute(xf, 'spaceGroup', spaceType)
      call xml_EndElement(xf, 'symmetry')
    endif
    call xml_EndElement(xf, 'crystal')

  end subroutine cmlAddCrystalDP

  ! -------------------------------------------------
  ! 2. creates and writes a SP <cell> element
  ! -------------------------------------------------

  subroutine cmlAddCrystalSP(xf, a, b, c, alpha, beta, gamma, id, title, dictref, conv, lenunits, angunits, spaceType, fmt)
    type(xmlf_t), intent(inout) :: xf
    real(kind=sp), intent(in)     :: a, b, c      ! cell parameters
    real(kind=sp), intent(in)     :: alpha        ! alpha cell parameter
    real(kind=sp), intent(in)     :: beta         ! beta cell parameter
    real(kind=sp), intent(in)     :: gamma        ! gamma cell parameter
    character(len=*), intent(in), optional :: id           ! id
    character(len=*), intent(in), optional :: title        ! title
    character(len=*), intent(in), optional :: dictref      ! dictref
    character(len=*), intent(in), optional :: conv         ! convention
    character(len=*), intent(in), optional :: lenunits     ! units for length (' ' = angstrom)
    character(len=*), intent(in), optional :: angunits     ! units for angles (' ' = degree)
    character(len=*), intent(in), optional :: spaceType    ! spacegroup
    character(len=*), intent(in), optional :: fmt          ! format

    ! Flush on entry and exit
    character(len=30) :: lunits, aunits
    character(len=10) :: formt

    if (present(fmt)) then
       formt = fmt
    else
       formt = spformat
    endif
    if (present(lenunits)) then
       lunits = lenunits
    else
       lunits = U_ANGSTR
    endif
    if (present(angunits)) then
       aunits = angunits
    else
       aunits = U_DEGREE
    endif

    call xml_NewElement(xf=xf, name='crystal')
    if (present(id))      call xml_AddAttribute(xf, 'id', id)
    if (present(title))   call xml_AddAttribute(xf, 'title', title)
    if (present(dictref)) call xml_AddAttribute(xf, 'dictRef', dictRef)
    if (present(conv))    call xml_AddAttribute(xf, 'convention', conv)
    call stmAddValue(xf=xf, value=a, title='a', dictref='cml:a', units=lunits, fmt=formt)
    call stmAddValue(xf=xf, value=b, title='b', dictref='cml:b', units=lunits, fmt=formt)
    call stmAddValue(xf=xf, value=c, title='c', dictref='cml:c', units=lunits, fmt=formt)
    call stmAddValue(xf=xf, value=alpha, title='alpha', dictref='cml:alpha', units=aunits, fmt=formt)
    call stmAddValue(xf=xf, value=beta,  title='beta',  dictref='cml:beta', units=aunits, fmt=formt)
    call stmAddValue(xf=xf, value=gamma, title='gamma', dictref='cml:gamma', units=aunits, fmt=formt)
    if (present(spaceType)) then
      call xml_NewElement(xf, 'symmetry')
      call xml_AddAttribute(xf, 'spaceGroup', spaceType)
      call xml_EndElement(xf, 'symmetry')
    endif
    call xml_EndElement(xf, 'crystal')


  end subroutine cmlAddCrystalSP
  
  
  ! -------------------------------------------------
  ! 1. creates and writes an DP <eigen> element
  ! -------------------------------------------------
  
  subroutine cmlAddEigenvalueDP(xf, n, eigvec, eigval, id, title, dictref, fmt)


    type(xmlf_t), intent(inout)            :: xf
    integer, intent(in)                    :: n              ! number of elements
    real(kind=dp), intent(in)              :: eigvec(n, *)   ! eigenvectors
    real(kind=dp), intent(in)              :: eigval(*)      ! eigenvalues
    character(len=*), intent(in), optional :: id             ! id
    character(len=*), intent(in), optional :: title          ! title
    character(len=*), intent(in), optional :: dictref        ! dictionary reference
    character(len=*), intent(in), optional :: fmt            ! format
    character(len=10):: formt

    if (present(fmt)) then
       formt = fmt
    else
       formt = dpformat
    endif

    ! Flush on entry and exit
    call xml_NewElement(xf, 'eigen')
    if (present(id))      call xml_AddAttribute(xf, 'id', id)
    if (present(title))   call xml_AddAttribute(xf, 'title', title)
    if (present(dictref)) call xml_AddAttribute(xf, 'dictRef', dictRef)
    call stmAddValue(xf=xf, value=eigval(1:n), title='eigenvalues', dictref=dictRef, fmt=fmt)
    call stmAddValue(xf=xf, value=eigvec(:n,:n), title='eigenvectors', fmt=fmt)
    call xml_EndElement(xf, 'eigen')

  end subroutine cmlAddEigenvalueDP



  ! -------------------------------------------------
  ! 2. creates and writes an SP <eigen> element
  ! -------------------------------------------------
  
  subroutine cmlAddEigenvalueSP(xf, n, eigvec, eigval, id, title, dictref, fmt)


    type(xmlf_t), intent(inout) :: xf
    integer, intent(in)          :: n              ! number of elements
    real(kind=sp), intent(in)     :: eigvec(n, *) ! eigenvectors
    real(kind=sp), intent(in)     :: eigval(*)      ! eigenvalues
    character(len=*), intent(in), optional :: id             ! id
    character(len=*), intent(in), optional :: title          ! title
    character(len=*), intent(in), optional :: dictref        ! dictionary reference
    character(len=*), intent(in), optional :: fmt            ! format
    character(len=10):: formt

    if (present(fmt)) then
       formt = fmt
    else
       formt = spformat
    endif

    ! Flush on entry and exit
    call xml_NewElement(xf, 'eigen')
    if (present(id))      call xml_AddAttribute(xf, 'id', id)
    if (present(title)) call xml_AddAttribute(xf, 'title', title)
    if (present(dictRef))   call xml_AddAttribute(xf, 'dictRef', dictref)
    call stmAddValue(xf=xf, value=eigval(1:n), title='eigenvalues', dictref=dictRef, fmt=fmt)
    call stmAddValue(xf=xf, value=eigvec(:n,:n), title='eigenvectors', fmt=fmt)
    call xml_EndElement(xf, 'eigen')

  end subroutine cmlAddEigenvalueSP

! =================================================
! basic CML routines
! =================================================

  
  ! -------------------------------------------------
  ! 1. adds DP xyz3 to start tag
  ! -------------------------------------------------
  
  subroutine CMLATXYZ39DP(xf, x3, y3, z3, fmt)
    type(xmlf_t), intent(inout)             :: xf
    real(kind=dp), intent(in)               :: x3, y3, z3 ! coordinates
    character(len=*), intent(in), optional  :: fmt        ! format

    if (present(fmt)) then
      call xml_AddAttribute(xf, 'xyz3', str(x3,fmt)//' '//str(y3,fmt)//' '//str(z3,fmt) )
    else
      call xml_AddAttribute(xf, 'xyz3', str(x3)//' '//str(y3)//' '//str(z3) )
    endif

  end subroutine CMLATXYZ39DP


  ! -------------------------------------------------
  ! 2. adds SP xyz3 to start tag
  ! -------------------------------------------------

  subroutine CMLATXYZ39SP(xf, x3, y3, z3, fmt)
    type(xmlf_t), intent(inout)             :: xf
    real(kind=sp), intent(in)               :: x3, y3, z3 ! coordinates
    character(len=*), intent(in), optional  :: fmt

    if (present(fmt)) then
      call xml_AddAttribute(xf, 'xyz3', str(x3,fmt)//' '//str(y3,fmt)//' '//str(z3,fmt) )
    else
      call xml_AddAttribute(xf, 'xyz3', str(x3)//' '//str(y3)//' '//str(z3) )
    endif

  end subroutine CMLATXYZ39SP
  
  ! -------------------------------------------------
  ! 1. adds DP xyzFrac to start tag
  ! -------------------------------------------------
  
  subroutine CMLATXYZFRACT9DP(xf, x3, y3, z3, fmt)
    type(xmlf_t), intent(inout)             :: xf
    real(kind=dp), intent(in)               :: x3, y3, z3 ! coordinates
    character(len=*), intent(in), optional  :: fmt        ! format

    if (present(fmt)) then
      call xml_AddAttribute(xf, 'xyzFrac', str(x3,fmt)//' '//str(y3,fmt)//' '//str(z3,fmt) )
    else
      call xml_AddAttribute(xf, 'xyzFrac', str(x3)//' '//str(y3)//' '//str(z3) )
    endif

  end subroutine CMLATXYZFRACT9DP

  ! -------------------------------------------------
  ! 2. adds SP xyzFrac to start tag
  ! -------------------------------------------------

  subroutine CMLATXYZFRACT9SP(xf, x3, y3, z3, fmt)
    type(xmlf_t), intent(inout)            :: xf
    real(kind=sp), intent(in)              :: x3, y3, z3 ! coordinates
    character(len=*), intent(in), optional :: fmt        ! format

    if (present(fmt)) then
      call xml_AddAttribute(xf, 'xyzFrac', str(x3,fmt)//' '//str(y3,fmt)//' '//str(z3,fmt) )
    else
      call xml_AddAttribute(xf, 'xyzFrac', str(x3)//' '//str(y3)//' '//str(z3) )
    endif

  end subroutine CMLATXYZFRACT9SP


  ! -------------------------------------------------
  ! 1. adds DP x3, y3, z3 to start tag
  ! -------------------------------------------------

  subroutine CMLATX39DP(xf, x3, y3, z3, fmt)
    type(xmlf_t), intent(inout)            :: xf
    real(kind=dp), intent(in)              :: x3, y3, z3 ! coordinates
    character(len=*), intent(in), optional :: fmt

    if (present(fmt)) then
      call xml_AddAttribute(xf, 'x3', str(x3,fmt))
      call xml_AddAttribute(xf, 'y3', str(y3,fmt))
      call xml_AddAttribute(xf, 'z3', str(z3,fmt))
    else
      call xml_AddAttribute(xf, 'x3', x3)
      call xml_AddAttribute(xf, 'y3', y3)
      call xml_AddAttribute(xf, 'z3', z3)
    endif

  end subroutine CMLATX39DP

  ! -------------------------------------------------
  ! 2. adds SP x3, y3, z3 to start tag
  ! -------------------------------------------------

  subroutine CMLATX39SP(xf, x3, y3, z3, fmt)
    type(xmlf_t), intent(inout)            :: xf
    real(kind=sp), intent(in)              :: x3, y3, z3 ! coordinates
    character(len=*), intent(in), optional :: fmt

    if (present(fmt)) then
      call xml_AddAttribute(xf, 'x3', str(x3,fmt))
      call xml_AddAttribute(xf, 'y3', str(y3,fmt))
      call xml_AddAttribute(xf, 'z3', str(z3,fmt))
    else
      call xml_AddAttribute(xf, 'x3', x3)
      call xml_AddAttribute(xf, 'y3', y3)
      call xml_AddAttribute(xf, 'z3', z3)
    endif

  end subroutine CMLATX39SP


  ! -------------------------------------------------
  ! 1. adds DP xFract, yFract, zFract to start tag
  ! -------------------------------------------------

  subroutine CMLATXF9DP(xf, xFract, yFract, zFract, fmt)
    type(xmlf_t), intent(inout)            :: xf
    real(kind=dp), intent(in)              :: xFract, yFract, zFract ! coordinates
    character(len=*), intent(in), optional :: fmt

    if (present(fmt)) then
      call xml_AddAttribute(xf, 'xFract', str(xFract,fmt))
      call xml_AddAttribute(xf, 'yFract', str(yFract,fmt))
      call xml_AddAttribute(xf, 'zFract', str(zFract,fmt))
    else
      call xml_AddAttribute(xf, 'xFract', xFract)
      call xml_AddAttribute(xf, 'yFract', yFract)
      call xml_AddAttribute(xf, 'zFract', zFract)
    endif

  end subroutine CMLATXF9DP
  
  ! -------------------------------------------------
  ! 2. adds SP xfrac, yFract, zFract to start tag
  ! -------------------------------------------------
  
  subroutine CMLATXF9SP(xf, xFract, yFract, zFract, fmt)
    type(xmlf_t), intent(inout)            :: xf
    real(kind=sp), intent(in)              :: xFract, yFract, zFract   ! fractional coordinates
    character(len=*), intent(in), optional :: fmt

    if (present(fmt)) then
      call xml_AddAttribute(xf, 'xFract', str(xFract,fmt))
      call xml_AddAttribute(xf, 'yFract', str(yFract,fmt))
      call xml_AddAttribute(xf, 'zFract', str(zFract,fmt))
    else
      call xml_AddAttribute(xf, 'xFract', xFract)
      call xml_AddAttribute(xf, 'yFract', yFract)
      call xml_AddAttribute(xf, 'zFract', zFract)
    endif

  end subroutine CMLATXF9SP


  ! -------------------------------------------------
  ! 1. adds DP x2, y2 to start tag
  ! -------------------------------------------------

  subroutine CMLATXY9DP(xf, x2, y2, fmt)
    type(xmlf_t), intent(inout)            :: xf
    real(kind=dp), intent(in)              :: x2, y2   ! coordinates
    character(len=*), intent(in), optional :: fmt      

    if (present(fmt)) then
      call xml_AddAttribute(xf, 'x2', str(x2,fmt))
      call xml_AddAttribute(xf, 'y2', str(y2,fmt))
    else
      call xml_AddAttribute(xf, 'x2', x2)
      call xml_AddAttribute(xf, 'y2', y2)
    endif

  end subroutine CMLATXY9DP

  ! -------------------------------------------------
  ! 2. adds SP x2, y2 to start tag
  ! -------------------------------------------------

  subroutine CMLATXY9SP(xf, x2, y2, fmt)
    type(xmlf_t), intent(inout)            :: xf
    real(kind=sp), intent(in)              :: x2, y2   ! coordinates
    character(len=*), intent(in), optional :: fmt 

    if (present(fmt)) then
      call xml_AddAttribute(xf, 'x2', str(x2,fmt))
      call xml_AddAttribute(xf, 'y2', str(y2,fmt))
    else
      call xml_AddAttribute(xf, 'x2', x2)
      call xml_AddAttribute(xf, 'y2', y2)
    endif

  end subroutine CMLATXY9SP

end module m_wcml_core

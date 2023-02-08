module unitsmod
  implicit none
  real(8),parameter::    pc  = 3.085677581d18   ! parsec in [cm]
  real(8),parameter::    mu  = 1.660539066d-24  ! g
  real(8),parameter:: Msolar = 1.989e33         ! g
  real(8),parameter::   kbol = 1.380649d-23     ! J/K
  real(8),parameter::   year = 365.0d0*24*60*60 ! sec  
end module unitsmod
      

module fieldmod
    implicit none
    integer:: incr
    real(8):: time,dt
    integer:: in,jn,kn
    integer:: izone,jzone,kzone
    integer:: igs,jgs,kgs
    integer:: is,js,ks,ie,je,ke
    real(8),dimension(:),allocatable:: x1b,x2b,dvl1a
    real(8),dimension(:),allocatable:: x1a,x2a
    real(8),dimension(:,:,:),allocatable:: d,v1,v2,v3,p,ei,gp
    real(8):: dx
    real(8):: gam,rho0,Eexp

end module fieldmod

program data_analysis
  use fieldmod
  implicit none
  integer:: fbeg, fend
  logical:: flag
  integer,parameter:: unitcon=100

  INQUIRE(FILE ="control.dat",EXIST = flag)
  if(flag) then
     open (unitcon,file="control.dat" &
     &        ,status='old',form='formatted')
     read (unitcon,*) fbeg,fend
     close(unitcon)
  endif

  FILENUMBER: do incr  = fbeg,fend
     write(6,*) "file index",incr
     call ReadData
     call Visualize1D
     call Integration
  enddo FILENUMBER

  stop
end program data_analysis

subroutine ReadData
  use fieldmod
  implicit none   
  character(20),parameter::dirname="../bindata/"
  character(40)::filename
  integer,parameter::unitinp=13
  integer,parameter::unitbin=14
  character(8)::dummy
  logical flag
  logical,save:: is_inited
  data is_inited / .false. /

  write(filename,'(a3,i5.5,a4)')"unf",incr,".dat"
  filename = trim(dirname)//filename

  INQUIRE(FILE =filename,EXIST = flag)
  if(.not. flag) then
     write(6,*) "FILE:",filename
     stop 'Cannot Open  data'
  endif
  open(unitinp,file=filename,status='old',form='formatted')
  read(unitinp,*) dummy,time,dt
  read(unitinp,*) dummy,izone,igs
  close(unitinp)
  in=izone+2*igs
  jn=1
  kn=1

  is=1+igs
  js=1
  ks=1
  ie=in-igs
  je=1
  ke=1

  if(.not. is_inited)then
     allocate( x1b(in),x1a(in),dvl1a(in))
     allocate( d(in,jn,kn))
     allocate(v1(in,jn,kn))
     allocate(v2(in,jn,kn))
     allocate(v3(in,jn,kn))
     allocate( p(in,jn,kn))
     allocate(ei(in,jn,kn))
     is_inited = .true.
  endif

  write(filename,'(a3,i5.5,a4)')"bin",incr,".dat"
  filename = trim(dirname)//filename
  open(unitbin,file=filename,status='old',form='binary')
  read(unitbin)x1b(:),x1a(:),dvl1a(:)
!  read(unitbin)x2b(:),x2a(:)
  read(unitbin)  d(:,:,:)
  read(unitbin) v1(:,:,:)
  read(unitbin) v2(:,:,:)
  read(unitbin) v3(:,:,:)
  read(unitbin)  p(:,:,:)
  read(unitbin) ei(:,:,:)
  close(unitbin)
  
  return
end subroutine ReadData

subroutine Visualize1D
  use unitsmod
  use fieldmod
  implicit none
  integer::i,j,k

  character(20),parameter::dirname="output/"
  character(40)::filename
  integer,parameter::unit1D=123

  logical,save:: is_inited
  data is_inited / .false. /

  if(.not. is_inited)then
     call makedirs(dirname)
     is_inited = .true.
  endif

  write(filename,'(a3,i5.5,a4)')"rpr",incr,".dat"
  filename = trim(dirname)//filename
  open(unit1D,file=filename,status='replace',form='formatted')

  write(unit1D,'(1a,4(1x,E12.3))') "#",time/year
!                                    12345678   1234567890123     1234567890123   123456789012
  write(unit1D,'(1a,4(1x,a13))') "#","1:r[pc] ","2:den[1/cm^3] ","3:p[erg/cm3] ","4:vel[km/s] "
  k=ks
  j=js
  do i=is,ie
     write(unit1D,'(1x,4(1x,E13.3))') x1b(i)/pc,d(i,j,k)/mu,p(i,j,k),v1(i,j,k)/1.0d5
  enddo
  close(unit1D)

  return
end subroutine Visualize1D

subroutine Integration
  use unitsmod
  use fieldmod
  implicit none
  integer::i,j,k

  character(20),parameter::dirname="output/"
  character(40)::filename
  integer,parameter::unittot=1234
  real(8)::Etot,pi

  logical,save:: is_inited
  data is_inited / .false. /

  if(.not. is_inited)then
     call makedirs(dirname)
     is_inited = .true.
  endif

  pi = acos(-1.0d0)

  Etot=0.0d0
  k=ks
  j=js
  do i=is,ie
     Etot = Etot + (0.5d0*d(i,j,k)*v1(i,j,k)**2+ei(i,j,k))*dvl1a(i)*4.0d0*pi
  enddo

  write(filename,'(a3,i5.5,a4)')"tot",incr,".dat"
  filename = trim(dirname)//filename
  open(unittot,file=filename,status='replace',form='formatted')

!  write(unittot,'(1a,4(1x,E12.3))') "#",time/year
!                                    12345678   1234567890123     1234567890123   123456789012
!  write(unittot,'(1a,4(1x,a13))') "#","1:r[pc] ","2:den[1/cm^3] ","3:p[erg/cm3] ","4:vel[km/s] "

  write(unittot,'(1x,4(1x,E13.3))') time/year,Etot
  close(unittot)

  return
end subroutine  Integration

subroutine makedirs(outdir)
  implicit none
  character(len=*), intent(in) :: outdir
  character(len=256) command
  write(command, *) 'if [ ! -d ', trim(outdir), ' ]; then mkdir -p ', trim(outdir), '; fi'
  write(*, *) trim(command)
  call system(command)
end subroutine makedirs


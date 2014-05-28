module sphericaldfMod

 private
 public :: initdf,maxE,distf,gasRfromq,rho,rhofromfi, &
  &         fifromr,totalmass,rmax,rmin,setparameters
 
 integer,parameter :: ngrid=6000
 real, parameter :: pi=3.1415926535897932385
 real :: r(0:ngrid),dens(0:ngrid),ddensdr(0:ngrid)
 real :: cmass(0:ngrid),fi(0:ngrid),df(0:ngrid) 
 real :: ddrhodfi2(0:ngrid)
 real :: extdens(0:ngrid),extmass(0:ngrid),tmass(0:ngrid)
 
 real, parameter :: F_ZERO_R_LIMIT=0.

 integer, parameter :: ntheta=50
 
! density parameters 
 real :: rs, rvir,rhos 
 real :: rcut,cnorm,rmax,rmin
   
 contains
 
 real function rho(r)
  real :: r
  if(r.LE.rvir) then
   rho=rhos*rs**3/r/(rs+r)**2
  else
   rho=rhos*cnorm*rs**2/(rs+r)**2*exp(-r**2/rcut**2)
  endif 
 end function
 
 real function drhodr(r)
  real :: r
  if(r.LE.rvir) then
   drhodr=-rho(r)*(1/r+2/(rs+r))
  else
   drhodr=-rho(r)*(2*r/rcut**2+2/(rs+r))
  endif 
 end function

 real function ddrhodr2(r)
  real :: r
  if(r.LE.rvir) then
   ddrhodr2=-drhodr(r)*(1/r+2/(rs+r))+rho(r)*(1/r**2+2/(rs+r)**2)
  else
   ddrhodr2=-drhodr(r)*(2*r/rcut**2+2/(rs+r))+rho(r)*(2/(rs+r)**2-2/rcut**2)
  endif 
 end function

 function maxE()
  real maxE
  maxE=fi(0)
 end function 

 function totalmass()
  real totalmass
  totalmass=tmass(ngrid)
 end function
 
 function totalcmass()
  real totalcmass
  totalcmass=cmass(ngrid)
 end function

 
 function distf(e) result(f)
  real :: f,e
  f=invertcumul(ngrid+1,df,fi,e)
 end function
  
 function gasRfromq(q) result(gasr)
  real :: gasr,q,cm 
  cm=q*cmass(ngrid)
  gasr=invertcumul(ngrid+1,r,cmass,cm)
 end function 
 
 function fifromr(rad) result (lfi)
  real :: rad,lfi
  lfi=invertcumul(ngrid+1,fi,r,rad)  
 end function
 
 function rhofromfi(rad) result (lrho)
  real :: rad,lrho
  lrho=invertcumul(ngrid+1,dens,fi,rad)  
 end function

 function int_theta(densfunc,r) result(s)
 real,external :: densfunc
 real :: dctheta,s,r
 integer :: is
  s=0
  dctheta=1.0/ntheta
  s=s+densfunc(0.,r)+densfunc(r,0.)
  do is=1,ntheta-1,2
    ctheta=is*dctheta
    s=s+4*densfunc(r*sqrt(1-ctheta**2),r*ctheta)
  enddo
  do is=2,ntheta-2,2
    ctheta=is*dctheta
    s=s+2*densfunc(r*sqrt(1-ctheta**2),r*ctheta)
  enddo
  s=s*dctheta/3.
  s=s
 end function

 subroutine setparameters(rscale,virR,rho0)
  real, optional :: rscale,virR,rho0
  
  if(present(rscale)) then
   rs=rscale
  else
   print*,'NFW scale length?'
   read*,rs
  endif 
   
  if(present(virR)) then
   rvir=virR
  else
   print*,'NFW virial radius?'
   read*,rvir
  endif 

  if(present(rho0)) then
   rhos=rho0
  else
   print*,'NFW density constant?'
   read*,rhos
  endif 
    
  rcut=SQRT(2.)*rvir
  cnorm=exp(rvir**2/rcut**2)/(rvir/rs)
  rmin=1.e-4*rcut
  rmax=6*rcut
   
 end subroutine

      
 subroutine initdf(densfunc)
  integer :: i,j
  real :: fac,int
  real, external :: densfunc
    
  fac=exp(log(rmax/rmin)/(1.*(ngrid-1)))  
!  fac=(rmax-rmin)/(ngrid-1.)

  r(1)=rmin
  dens(1)=rho(rmin)
  ddensdr(1)=drhodr(rmin)
  do i=2,ngrid-1
   r(i)=r(i-1)*fac
!   r(i)=r(i-1)+fac
   dens(i)=rho(r(i))
   ddensdr(i)=drhodr(r(i))
  enddo
  r(ngrid)=rmax  
  dens(ngrid)=rho(rmax)
  ddensdr(ngrid)=drhodr(rmax)
  r(0)=0.
  dens(0)=dens(1) ! assumption !
  ddensdr(0)=0.
!  dens(0)=(4*dens(1)-dens(2))/3.
!  ddensdr(0)=(dens(1)-dens(0))/r(1)

! external density  averaged over theta
  extdens(0)=1/3.*densfunc(0.,rmin)+2./3.*densfunc(rmin,0.)
  do i=1,ngrid
   extdens(i)=int_theta(densfunc,r(i))
  enddo

  cmass(0.)=0.
  cmass(1.)=4/3.*Pi*r(1)**3*dens(0)
  do i=2,ngrid
   cmass(i)=cmass(i-1)+4*Pi*(r(i)-r(i-1))*(r(i)**2*dens(i)+r(i-1)**2*dens(i-1))/2.
  enddo

  extmass(0)=0.
  extmass(1)=4/3.*Pi*r(1)**3*extdens(0)
  do i=2,ngrid
   extmass(i)=extmass(i-1)+4*Pi*(r(i)-r(i-1))*(r(i)**2*extdens(i)+r(i-1)**2*extdens(i-1))/2.
  enddo

  print*,'halo reports a mass of:', cmass(ngrid)
  print*,'and an external mass of:', extmass(ngrid)
  
  tmass=cmass+extmass
  
  fi(ngrid)=0 
  do i=ngrid-1,1,-1
   fi(i)=fi(i+1)+(r(i+1)-r(i))*(tmass(i)/r(i)**2+tmass(i+1)/r(i+1)**2)/2.
  enddo
  fi(0)=fi(1)+r(1)*(F_ZERO_R_LIMIT+tmass(1)/r(1)**2)/2.
 
  do i=1,ngrid
   ddrhodfi2(i)=(r(i)**2/tmass(i))**2* &
    ((2/r(i)-4*Pi*r(i)**2*(dens(i)+extdens(i))/tmass(i))*ddensdr(i)+ddrhodr2(r(i)))
  enddo
  ddrhodfi2(0)=ddrhodfi2(1)

  df(ngrid)=0.
  do i=ngrid-1,1,-1
   int=0
   do j=ngrid-1,i+1,-1
   int=int+(fi(j)-fi(j+1))* &
       (ddrhodfi2(j)/sqrt(fi(i)-fi(j))+ddrhodfi2(j+1)/sqrt(fi(i)-fi(j+1)))/2.
   enddo
   int=int+2./3.*Sqrt((fi(i)-fi(i+1)))*(2*ddrhodfi2(i)+ddrhodfi2(i+1))
   df(i)=1/sqrt(8.)/pi**2*(int-1/sqrt(fi(i))*ddensdr(ngrid)*r(ngrid)**2/cmass(ngrid))
  enddo
  df(0)=df(1)

  open(unit=1,file='halo.df',status='UNKNOWN')
  do i=1,ngrid
  write(1,*) fi(i),df(i)
  enddo
  close(1)
  
! print*,'rmax,fi0,cmass:', rmax,fi(0),cmass(ngrid)
 
 end subroutine
 
  function invertcumul(n,xlist,ylist,y) result(x)
  integer :: n,bin,up,low
  real :: xlist(n),ylist(n),x,y,u,s
  
  if(ylist(1).LT.ylist(n)) then
   s=1
  else
   s=-1
  endif  
  
  if(s*y.LE.s*ylist(1)) then
   x=xlist(1)
   return
  endif
  if(s*y.GE.s*ylist(n)) then
   x=xlist(n)
   return
  endif
  up=n
  low=1
  do while((up-low).GT.1)
   bin=(low+up)/2
   if(s*y.LT.s*ylist(bin)) then
    up=bin
   else
    low=bin
   endif   
  enddo 
  bin=up
  u=(y-ylist(bin-1))/(ylist(bin)-ylist(bin-1))
  x=(1-u)*xlist(bin-1)+u*xlist(bin)  
  return
  end function
 
end module sphericaldfMod

 real function zerofunc(r,z)
  zerofunc=0.
 end function

subroutine sethalodf(rscl,rv,rhs)
 use sphericaldfMod
 real rscl,rv,rhs
 call setparameters(rscl,rv,rhs)
end subroutine

subroutine inithalodf(densfunc)
 use sphericaldfMod
 real, external :: zerofunc
 real, external, optional :: densfunc
 if(present(densfunc)) then
  call initdf(densfunc)
 else
  call initdf(zerofunc)
 endif
end subroutine

function halodfpsi00()
 use sphericaldfMod
 real halodfpsi00
 halodfpsi00=-maxE() 
end function

function halodffi(r)
 use sphericaldfMod
 real halodffi,r
! r>rmax??
 if(r.LT.rmax) then
  halodffi=-fifromr(r)
 else
  halodffi=totalmass()*(1/rmax-1/r)
 endif
end function

function Fhalo3(E)
 use sphericaldfMod
 real Fhalo3,E,nE
 Fhalo3=0
 if(E.LT.-maxE()) then
  print*, 'EEEEKS'
  print*, E, -maxE()
  stop
 endif 
 nE=-E ! note: E is expected always to be > psi0!!
 if(nE.LE.0) return
 Fhalo3=distf(nE)
end function 

function halodfdenspsi(psi,psi0)
 use sphericaldfMod
  real halodfdenspsi,psi,psi0,npsi
 halodfdenspsi=0
 npsi=-(psi-psi0+halodfpsi00())
 if(npsi.LE.0) return
 halodfdenspsi=rhofromfi(npsi)
end function

function halodfdens(r,z) result(x)
 use sphericaldfMod
  real r,z,x
  x=rho(sqrt(r*r+z*z))
end function 

function halormax()
 use sphericaldfMod
 real halormax
 halormax=rmax
end function 

function halormin()
 use sphericaldfMod
 real halormin
 halormin=rmin
end function 


 function sdens(r,z) 
  real r,z,sdens  
  real rmdisk,zdisk,outdisk,drtrunc,erfarg,truncfac,con,diskconst,rdisk
  zdisk=0.5
  rdisk=3
  rmdisk=50.
  diskconst=rmdisk/(4.0*3.1415*rdisk**2*zdisk)
  outdisk=12
  drtrunc=.5
  sdens = 0
  if( abs(z/zdisk) .gt. 30.) return
   erfarg=(r-outdisk)/1.4142136/drtrunc
  if (erfarg.gt.4.) return
  if (erfarg.lt.-4) then
   trunfac=1
  else
   trunfac=0.5*erfc(erfarg)
  endif
  if (z.eq.0.) then
   con=1
  else
   con = exp(-abs(z/zdisk))
   con = (2.0*con/(1.0 + con*con))**2
  endif
  sdens = diskconst*exp(-r/rdisk)*con*trunfac 
  end function

! program test
!  use sphericaldfMod
!  implicit none
!    integer i,j,np,count
!    real, external ::sdens,zerofunc
!  
!  call initdf(sdens,6.,72.,0.04)
!
!  do i=0,ngrid-1
!   print*,r(i),dens(i),ddensdr(i)
!   print*,r(i),extdens(i),extmass(i)
!   print*,r(i),fi(i),df(i)
!  enddo  
! end program

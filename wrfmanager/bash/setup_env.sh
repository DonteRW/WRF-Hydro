# User specific environment and startup programs
# PATH
export PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin

# MPICH
export PATH=/home/erick/MPICH/mpich-3.1.2/install/bin:$PATH

# jasper
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/jasper/1.701.1/lib

# NETCDF
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/erick/NCAR/old_releases/netcdf/netcdf-4.1.3-el6-x86_64/lib

# NCAR
export NCARG_ROOT=/home/erick/NCAR/old_releases/ncl/ncl_ncarg-6.1.0.Linux_RedHat_x86_64_nodap_gcc444
export PATH=$NCARG_ROOT/bin:$PATH
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$NCARG_ROOT/lib

 #Just to be sure:
export HOME=/home/erick

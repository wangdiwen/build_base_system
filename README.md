Usage:

./burn_system_60g_min.sh -a -d

Note:

    The latest main bash script is burn_system_60g_min.sh,
    
    60g means 60G SSD disk,
    
    min means custom-made system is the mini system, just has two startup mode,
    
    -a  means auto process build,
    
    -d  means burn the mini system to a mounted disk, the dev is '/dev/sdb',
    
Doc:
    
    In a standard Linux system, system disk maybe /dev/sda, or other devices,
    
    in this script shell, we resume sys disk is /dev/sda, the default burn sys disk is /dev/sdb,
    
    but you can config the burn sys disk in a configure file in path -> 'update/data/config'.


Author: wangdiwen

  Date: 2014-05-04
  
E-mail: dw_wang126@126.com


Good luck.

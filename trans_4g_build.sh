#!/bin/bash


echo "=============== Trans Script to Build 4G dom System ==================="
echo
echo "Machine is : 10.4.89.100 (tvwall)"
echo "Root Passwd: 123456"
echo

expect -c "
    set timeout 100
    spawn scp -r burn_system_4g.sh tvwall_navidia_pre.sh burn_data update root@10.4.89.100:/root
    expect {
        \"Are you sure\" { send \"yes\n\"; exp_continue; }
        \"password\" { send \"123456\n\"; }
    }
    expect eof
"
echo
echo "=============== Trans OK !!!"
echo

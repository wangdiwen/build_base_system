#!/bin/bash

echo ''
echo 'host -> 10.4.89.100'
echo 'root -> 123456'
echo ''

expect -c "
	set timeout 10
	spawn scp burn_system_60g_min.sh root@10.4.89.100:/root/
	expect {
		\"*yes/no\" { send \"yes\n\"; exp_continue; }
		\"*password\" { send \"123456\n\"; }
	}
	expect eof"

expect -c "
	set timeout 300
	spawn scp -r burn_data update root@10.4.89.100:/root
	expect {
		\"*yes/no\" { send \"yes\n\"; exp_continue; }
		\"*password\" { send \"123456\n\"; }
	}
	expect eof"

echo ''
echo 'sync ========> ok '
echo ''

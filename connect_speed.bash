#!/usr/bin/bash
#
# build multiple versions of proxysql and benchmark
#


####################################################################################################

DB='mysql57'
OFFSET=0
PORT=$(expr $OFFSET + 6033)

fn_multiport () {
	local MPORT=""
	for M in $(seq $MULTI); do
		MPORT+="0.0.0.0:$(expr $OFFSET + 6032 + $M);"
	done
	echo "${MPORT::-1}"
}

fn_mquery () {
	mysql --default-auth=mysql_native_password -uroot -proot -h127.0.0.1 -P3306 -e "${1}" 2>&1 | grep -vP "mysql: .?Warning"
}

fn_pquery () {
	mysql --default-auth=mysql_native_password -uadmin -padmin -h127.0.0.1 -P6032 -e "${1}" 2>&1 | grep -vP "mysql: .?Warning"
}

fn_build () {
	OFFSET=0
	for VER in ${VERS}; do

#		let OFFSET+=10000

		#rm -rf proxysql.${VER} || true
		echo "============================================================================================="
		echo "ProxySQL '${VER}'"
		if [[ ! -d proxysql.${VER} ]]; then
			echo "Cloning repo ..."
			git clone https://github.com/sysown/proxysql.git proxysql.${VER}
			git -C proxysql.${VER} checkout ${VER} 2> /dev/null
		fi

		pushd proxysql.${VER} &> /dev/null
		if [[ ! -f src/proxysql ]]; then
			echo "Building ..."
			make -j$(nproc) &> /dev/null
		fi

		echo "Configuring ..."
		#sed -ir "0,/threads=[0-9]\+/{s//threads=$(expr $NCPUS '/' $MULTI)/}" ./src/proxysql.cfg
		#sed -ir "0,/threads=[0-9]\+/{s//threads=$(expr 1 '*' $MULTI)/}" ./src/proxysql.cfg
		sed -ir "0,/threads=[0-9]\+/{s//threads=1/}" ./src/proxysql.cfg
		grep 'threads=' src/proxysql.cfg | head -1
		sed -ir "0,/max_connections=[0-9]\+/{s//max_connections=65536/}" ./src/proxysql.cfg
		grep 'max_connections=' src/proxysql.cfg | head -1
		sed -ir "0,/max_user_connections=[0-9]\+/{s//max_user_connections=65536/}" ./src/proxysql.cfg
		grep 'max_user_connections=' src/proxysql.cfg | head -1
		sed -ir "s/\"0.0.0.0:[0-9]\?6032\"/\"0.0.0.0:$(expr $OFFSET + 6032)\"/" ./src/proxysql.cfg
		sed -ir "s/\"0.0.0.0:[0-9]\?6033.\+/\"$(fn_multiport)\"/" ./src/proxysql.cfg
		grep '0.0.0.0' src/proxysql.cfg
		rm -f ./src/*.db

		#./src/proxysql --idle-threads --sqlite3-server -f -c ./src/proxysql.cfg -D ./src &
		#./src/proxysql -f -c ./src/proxysql.cfg -D ./src  &> /dev/null &
		#sleep 5

		#mysql --default-auth=mysql_native_password -u admin -padmin -h 127.0.0.1 -P $(expr $OFFSET + 6032) -e "INSERT INTO mysql_users (username,password) VALUES ('sbtest','sbtest'); LOAD mysql users TO RUNTIME; SAVE mysql users TO DISK;" 2>&1 | grep -vP "mysql: .?Warning"
		#mysql --default-auth=mysql_native_password -u admin -padmin -h 127.0.0.1 -P $(expr $OFFSET + 6032) -e "SET mysql-interfaces = '0.0.0.0:$(expr $OFFSET + 6033),0.0.0.0:$(expr $OFFSET + 6034),0.0.0.0:$(expr $OFFSET + 6035),0.0.0.0:$(expr $OFFSET + 6036)';" 2>&1 | grep -vP "mysql: .?Warning"
		#mysql --default-auth=mysql_native_password -u admin -padmin -h 127.0.0.1 -P $(expr $OFFSET + 6032) -e "SELECT @@version;" -E 2>&1 | grep -vP "mysql: .?Warning" | grep version

		popd &> /dev/null
	done
}

fn_gitver() {
	mysql --default-auth=mysql_native_password -u admin -padmin -h 127.0.0.1 -P $(expr $OFFSET + 6032) -e "SELECT @@version;" -E 2>&1 | grep -vP "mysql: .?Warning" | grep version
}

fn_waitstate() {
	MAXWAIT=$@
#	echo "============================================================================================="
	WAIT=$(netstat -ntpa | grep WAIT | wc -l)
	echo -n "Waiting for $WAIT connections to close ..."
	while [[ $WAIT -ge 100 ]]; do
		echo -n "."
		sleep 1
		WAIT=$(netstat -ntpa | grep WAIT | wc -l)
	done
	echo
	echo "Continuing with $WAIT connections in WAIT state ..."
	#sleep 60
}

fn_benchmark () {
	OFFSET=0
	for VER in ${VERS}; do

		SUMM=0
#		let OFFSET+=10000

		#CMD="./connect_speed -i 0 -c 1000 -u sbtest -p sbtest -h 127.0.0.1 -P $(expr $OFFSET + 6033) -t 10 -q 0"
		CMD=$(eval echo "${1}")

		echo "Starting proxysql $VER ..."
		killall proxysql
#		docker-compose -p connect_speed down
		sleep 60
#		./proxysql.${VER}/src/proxysql -f -c ./proxysql.${VER}/src/proxysql.cfg -D ./proxysql.${VER}/src &> /dev/null &
		pushd proxysql.${VER}/src &> /dev/null
		./proxysql -f -D . &> /dev/null &
		popd &> /dev/null

#		docker-compose -p connect_speed up -d ${DB} && sleep 30

		CNT=$(netstat -ntpl | grep -P ':\d?60[3456789]\d' | uniq -c | grep -v 6032 | wc -l)
		echo -n "Waiting for $MULTI ports to listen ..."
		while [[ ! $CNT == $MULTI ]]; do
			echo -n "."
			sleep 1
			CNT=$(netstat -ntpl | grep -P ':\d?60[3456789]\d' | uniq -c | grep -v 6032 | wc -l)
		done
		echo
#		netstat -ntpl | grep -P ':\d60[3456789]\d' | uniq -c

		mysql --default-auth=mysql_native_password -u admin -padmin -h 127.0.0.1 -P $(expr $OFFSET + 6032) -e "INSERT INTO mysql_users (username,password) VALUES ('sbtest','sbtest'); LOAD mysql users TO RUNTIME; SAVE mysql users TO DISK;" 2>&1 | grep -vP "mysql: .?Warning"
#		mysql --default-auth=mysql_native_password -u admin -padmin -h 127.0.0.1 -P $(expr $OFFSET + 6032) -e "SET admin-admin_credentials='admin:admin;cluster1:secret1pass;sbtest:sbtest'; LOAD admin variables TO RUNTIME; SAVE admin variables TO DISK;" 2>&1 | grep -vP "mysql: .?Warning"
#		fn_pquery "INSERT INTO mysql_users (username,password,fast_forward) VALUES ('sbtest','sbtest',0); LOAD MYSQL USERS TO RUNTIME;"
#		fn_pquery "DELETE FROM mysql_servers; INSERT INTO mysql_servers (hostgroup_id,hostname,port,max_connections) VALUES (0,'testinfra-${DB}',3306,1000); LOAD MYSQL SERVERS TO RUNTIME;"
		echo "Benchmark $(fn_gitver) on port $(expr $OFFSET + 6033)+ ..."
		echo "CMD: '${CMD}'"

		for N in $(seq $LOOP); do

			#grep </proc/net/tcp -c '^ *[0-9]\+: [0-9A-F: ]\{27\} 01 '
			#cat /proc/net/softnet_stat | awk '{print $2}' | grep -v 00000000

			fn_waitstate 100
			LOG=$($CMD 2>&1 | uniq -c)

#			netstat -ntpa | grep -i WAIT

			#grep </proc/net/tcp -c '^ *[0-9]\+: [0-9A-F: ]\{27\} 01 '
			#cat /proc/net/softnet_stat | awk '{print $2}' | grep -v 00000000

			echo "${LOG}"
			let SUMM+=$(echo ${LOG} | grep -Po '\d+(?=ms)')


			sleep ${PAUSE}
		done
		CONN=$(echo $CMD | grep -Po "(?<=\-c )[0-9]+")
		TRDS=$(echo $CMD | grep -Po "(?<=\-t )[0-9]+")
		TOTAL=$(expr $CONN '*' $TRDS '*' $LOOP)
		CPS=$(expr $TOTAL '*' 1000 '/' $SUMM)
		echo "SUMMARY: ${LOOP} runs, total $TOTAL connections, in ${SUMM}ms, at $CPS conn/s"

#		docker-compose -p connect_speed down
		while [[ $(netstat -ntpl) =~ proxysql ]]; do 
			killall proxysql
			sleep ${PAUSE}
		done

		echo "============================================================================================="
	done
}

fn_sysstats () {
	echo "============================================================================================="
	echo "OS: $(source /etc/os-release; echo ${PRETTY_NAME})"
	echo "Kernel: $(uname -a)"
	inxi
	echo "============================================================================================="
	sysctl -w net.core.somaxconn=65535
	sysctl -w net.core.netdev_max_backlog=65535
	sysctl -w vm.max_map_count=536870912
	echo "============================================================================================="
	ulimit -n 64000
	ulimit -a
	echo "============================================================================================="
	CNT=$(netstat -ntpl | grep -P ':\d60[3456789]\d' | uniq -c | grep -v 6032 | wc -l)
	PRT=$(expr $MULTI '*' $(echo $VERS | wc -w))
#	while [[ ! $CNT == $PRT ]]; do
#		echo "Waiting 10s for all ports to listen ..."
#		sleep 10
#		CNT=$(netstat -ntpl | grep -P ':\d60[3456789]\d' | uniq -c | grep -v 6032 | wc -l)
#	done
#	echo "Continuing with $(echo $VERS | wc -w) * $MULTI ports listening ..."
#	netstat -ntpl | grep -P ':\d60[3456789]\d' | uniq -c

}

####################################################################################################
# RUN
####################################################################################################

NCPUS=32
MULTI=1
VERS="v1.4.16 v2.0.17 v2.3.2 v2.5.5 v2.x v2.6.0-update_to_openssl_v3.1.5 v2.6.0-update_to_openssl_v3.2.1"
#VERS="v2.6.0-update_to_openssl_v3.1.5 v2.6.0-update_to_openssl_v3.2.1"
#VERS="v2.x v2.5.5 v2.3.2 v2.0.17 v1.4.16"
#VERS="v2.3.2"
LOOP=3
PAUSE=10

killall proxysql
sleep 5

fn_build

fn_sysstats

fn_benchmark "./connect_speed -i 0 -c 1000 -u sbtest -p sbtest -h 127.0.0.1 -P $PORT -M $MULTI -t 32 -q 0"
#fn_benchmark "./connect_speed -i 0 -c 1000 -u sbtest -p sbtest -h 127.0.0.1 -S required -P $PORT -M $MULTI -t 32 -q 0"

# test admmin port with query
#fn_benchmark "./connect_speed -i 0 -c 1000 -u admin -p admin -h 127.0.0.1 -P 6032 -M 1 -t 32 -q 1"
#fn_benchmark "./connect_speed -i 0 -c 1000 -u admin -p admin -h 127.0.0.1 -S required -P 6032 -M 1 -t 32 -q 1"

killall proxysql

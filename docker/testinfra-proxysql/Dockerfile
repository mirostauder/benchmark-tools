FROM proxysql/proxysql:latest-debian

MAINTAINER Miro Stauder <miro@sysown.com>

# debugging tools
RUN apt-get -y update && \
	apt-get -y install \
		mariadb-client \
		gdb net-tools \
		mc \
		psutils \
		tcpdump

RUN sed -i 's/admin:admin/admin:admin;test:test/' /etc/proxysql.cnf

CMD ["bash", "-c", "proxysql -f --idle-threads -D /var/lib/proxysql 2>&1 | tee /var/lib/proxysql/proxysql.log"]

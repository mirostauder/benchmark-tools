FROM proxysql/packaging:pkgtest-debian11

MAINTAINER Miro Stauder <miro@sysown.com>

# debugging tools
RUN apt-get -y update && \
	apt-get -y install \
		mariadb-client \
		gdb net-tools \
		mc \
		psmisc \
		tcpdump

# pre-built dev branch package
COPY ./proxysql_*-debian11_amd64.deb ./
RUN yes | dpkg -i ./proxysql_*-debian11_amd64.deb

RUN sed -i 's/admin:admin/admin:admin;test:test/' /etc/proxysql.cnf

CMD ["bash", "-c", "proxysql -f --idle-threads -D /var/lib/proxysql 2>&1 | tee /var/lib/proxysql/proxysql.log"]

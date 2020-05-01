#!/bin/bash

if [ "$(id -u)" = "0" ]; then
	gosu postgres "$BASH_SOURCE"
	gosu sonar "$BASH_SOURCE"
	gosu nexus "$BASH_SOURCE"
	exec "$@"
elif [ "$(id -u)" = "1500" ]; then
	if [ ! -f /opt/postgresql/postgres-config ]; then
		touch /opt/postgresql/configured
		initdb -E UTF8 -D /opt/postgresql-data
		pg_ctl -D /opt/postgresql-data -l /opt/postgresql-log/log start
		createuser sonar
		createdb -O sonar sonar
		psql -d sonar -c "ALTER USER sonar WITH ENCRYPTED PASSWORD 'sonar';"
	else
		pg_ctl -D /opt/postgresql-data -l /opt/postgresql-log/log start
	fi
elif [ "$(id -u)" = "1600" ]; then
	if [ ! -f /opt/nexus/configured ]; then
		touch /opt/nexus/configured
	fi
	/etc/init.d/nexus start
elif [ "$(id -u)" = "1700" ]; then
	if [ ! -f /opt/sonar/configured ]; then
		touch /opt/sonar/configured
		sed -i -e "s/#sonar.jdbc.username=.*$/sonar.jdbc.username=sonar/" /opt/sonarqube/conf/sonar.properties
		sed -i -e "s/#sonar.jdbc.password=.*$/sonar.jdbc.password=sonar/" /opt/sonarqube/conf/sonar.properties
		sed -i -e "s/#sonar.jdbc.url=jdbc:postgresql:\/\/localhost\/sonarqube?currentSchema=my_schema.*$/sonar.jdbc.url=jdbc:postgresql:\/\/localhost\/sonar/" /opt/sonarqube/conf/sonar.properties
	fi
	/etc/init.d/sonar start
else
	exit 1
fi

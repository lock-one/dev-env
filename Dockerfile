FROM ubuntu:20.04

WORKDIR /tmp

# Utilities
RUN apt-get update \
    && apt-get install -y wget make gcc zlib1g-dev libreadline6-dev unzip \
    && rm -rf /var/lib/apt/lists/*

# JRE 8
RUN wget --quiet https://cdn.azul.com/zulu/bin/zulu8.46.0.19-ca-jre8.0.252-linux_x64.tar.gz \
    && tar -zxf zulu*.tar.gz \
    && rm zulu*.gz \
    && mkdir -p /usr/lib/jvm \
    && mv /tmp/zulu* /usr/lib/jvm/zulu8 \
    && update-alternatives --install /usr/bin/java java /usr/lib/jvm/zulu8/bin/java 100

ENV JAVA_HOME /usr/lib/jvm/zulu8

# JRE 11
RUN wget --quiet https://cdn.azul.com/zulu/bin/zulu11.39.15-ca-jre11.0.7-linux_x64.tar.gz \
    && tar -zxf zulu*.tar.gz \
    && rm zulu*.gz \
    && mkdir -p /usr/lib/jvm \
    && mv /tmp/zulu* /usr/lib/jvm/zulu11 \
    && update-alternatives --install /usr/bin/java java /usr/lib/jvm/zulu11/bin/java 10

# Administrators group
RUN groupadd -g 5000 administrators

# Postgres 12
RUN wget --quiet https://ftp.postgresql.org/pub/source/v12.2/postgresql-12.2.tar.gz \
    && tar -zxf postgresql-*.tar.gz \
    && rm postgresql-*.tar.gz \
    && mkdir /opt/postgresql \
    && (cd postgresql-* && ./configure --prefix=/opt/postgresql) \
    && (cd postgresql-* && make --quiet) \
    && (cd postgresql-* && make install --quiet) \
    && adduser --no-create-home --disabled-password --gecos "" -gid 5000 -u 1500 postgres \
    && passwd -d postgres \
    && chown -R postgres /opt/postgresql \
    && mkdir /opt/postgresql-data \
    && chown -R postgres /opt/postgresql-data \
    && mkdir /opt/postgresql-log \
    && chown -R postgres /opt/postgresql-log \
    && usermod -d /opt/postgresql postgres \
    && ln -s /opt/postgresql/bin/psql /etc/init.d/psql

EXPOSE 5432

ENV PATH $PATH:/opt/postgresql/bin

# Nexus 3
RUN wget --quiet http://download.sonatype.com/nexus/3/nexus-3.22.1-02-unix.tar.gz \
    && tar -zxf nexus-*.tar.gz \
    && rm nexus-*.gz \
    && mv /tmp/nexus-* /opt/nexus \
    && mv /tmp/sonatype-work /opt/sonatype-work \
    && mkdir /opt/sonatype-work/nexus3/etc \
    && adduser --no-create-home --disabled-password --gecos "" -gid 5000 -u 1600 nexus \
    && passwd -d nexus \
    && chown -R nexus /opt/nexus \
    && chown -R nexus /opt/sonatype-work \
    && usermod -d /opt/nexus nexus \
    && sed -i -e 's/#run_as_user.*$/run_as_user=nexus/' /opt/nexus/bin/nexus.rc \
    && ln -s /opt/nexus/bin/nexus /etc/init.d/nexus

EXPOSE 8081

# Sonar 8
RUN wget --quiet https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-8.2.0.32929.zip \
    && unzip -qq sonarqube-8*.zip \
    && rm sonarqube-8*.zip \
    && mv /tmp/sonarqube-* /opt/sonarqube \
    && adduser --no-create-home --disabled-password --gecos "" -gid 5000 -u 1700 sonar \
    && passwd -d sonar \
    && chown -R sonar /opt/sonarqube \
    && usermod -d /opt/sonarqube sonar \
    && sed -i -e 's/#RUN_AS_USER=.*$/RUN_AS_USER=sonar/' /opt/sonarqube/bin/linux-x86-64/sonar.sh \
    && sed -i -e 's/wrapper.java.command=java.*$/wrapper.java.command=\/usr\/lib\/jvm\/zulu11\/bin\/java/' /opt/sonarqube/conf/wrapper.conf \
    && ln -s /opt/sonarqube/bin/linux-x86-64/sonar.sh /etc/init.d/sonar

EXPOSE 9000

# Cleanup
RUN apt-get purge -y wget make gcc zlib1g-dev libreadline6-dev unzip \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/*

# Gosu
ENV GOSU_VERSION 1.12
RUN set -eux; \
	savedAptMark="$(apt-mark showmanual)"; \
    echo "nameserver 8.8.8.8" >> /etc/resolv.conf; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates wget gnupg dirmngr; \
	rm -rf /var/lib/apt/lists/*; \
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget --quiet -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget --quiet -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	chmod +x /usr/local/bin/gosu; \
	gosu --version; \
	gosu nobody true

WORKDIR /

RUN mkdir /opt/status \
    && chown :administrators /opt/status \
    && chmod -R 770 /opt/status

# Entry point
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["sh"]
FROM fedora:41 AS libnice

WORKDIR /usr

RUN yum install git ninja-build meson gcc cmake -y
RUN yum install glib2-devel pkgconf-pkg-config gnutls-devel -y

RUN git clone --branch 0.1.23 --depth 1 https://gitlab.freedesktop.org/libnice/libnice


WORKDIR /usr/libnice
RUN meson setup builddir --prefix=/usr && \
	ninja -C builddir && \
	DESTDIR=/tmp/libnice-install ninja -C builddir install

FROM fedora:41 

WORKDIR /usr

RUN yum install git cmake ninja-build meson which -y
RUN yum install libmicrohttpd-devel jansson-devel openssl-devel libsrtp-devel sofia-sip-devel glib2-devel opus-devel libogg-devel libcurl-devel pkgconfig libconfig-devel libtool autoconf automake pkg-config gnutls -y

RUN git clone --branch v1.3.3 --depth 1 https://github.com/meetecho/janus-gateway.git

COPY --from=libnice /tmp/libnice-install/usr /usr
RUN ldconfig

WORKDIR /usr/janus-gateway

RUN sh autogen.sh
RUN ./configure --disable-rabbitmq --disable-mqtt --disable-websockets --prefix=/opt/janus
RUN make
RUN make install
RUN make configs

WORKDIR /opt/janus/etc/janus
RUN rm -f janus.plugin.videoroom.jcfg
RUN rm -f janus.jcfg
COPY ./janus.plugin.videoroom.jcfg .
COPY ./janus.jcfg .

WORKDIR /opt/janus/bin
CMD ["/opt/janus/bin/janus"]

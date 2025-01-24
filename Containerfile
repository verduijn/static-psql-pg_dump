FROM debian:latest AS builder


RUN apt-get update -y && apt-get install -y \
    build-essential  \
    wget \
    zip \
    libicu-dev \
    libbison-dev \
    meson \
    flex 


# Download and compile OpenSSL with a custom install path
ENV OPENSSL_VERSION=3.2.3
WORKDIR /build
ENV prefix=/build
RUN wget https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz && \
    tar -xzf openssl-$OPENSSL_VERSION.tar.gz && \
    cd openssl-$OPENSSL_VERSION && \
    ./Configure linux-x86_64 no-shared no-dso --static \
    --prefix $prefix --openssldir=/prefix && \
    make -j 10 && \
    make install_sw && \
    cd .. && \
    rm -rf openssl-$OPENSSL_VERSION*

ARG POSTGRES_VERSION=REL_16_6

RUN wget https://github.com/postgres/postgres/archive/refs/tags/${POSTGRES_VERSION}.zip && unzip *
WORKDIR /build/postgres-${POSTGRES_VERSION}
RUN meson setup builddir --default-library=static -Dssl=openssl \
    && meson compile -C builddir

# build pg_dump with openssl / ligpq static
RUN cd builddir && cc  -o /tmp/pg_dump src/bin/pg_dump/pg_dump.p/common.c.o src/bin/pg_dump/pg_dump.p/pg_dump.c.o src/bin/pg_dump/pg_dump.p/pg_dump_sort.c.o -Wl,--as-needed -Wl,--no-undefined '-Wl,-rpath,$ORIGIN/../../interfaces/libpq:XXXXXXX' -Wl,-rpath-link,/build/postgres-${POSTGRES_VERSION}/builddir/src/interfaces/libpq -Wl,--start-group src/bin/pg_dump/libpgdump_common.a src/fe_utils/libpgfeutils.a src/common/libpgcommon.a src/common/libpgcommon_ryu.a src/common/libpgcommon_config_info.a src/port/libpgport.a src/port/libpgport_crc.a src/interfaces/libpq/libpq.a -Wl,-Bstatic -lssl -lcrypto -Wl,-Bdynamic -lm -Wl,--end-group
# uncomment to build completely static
# RUN cd builddir && cc  -o /tmp/pg_dump src/bin/pg_dump/pg_dump.p/common.c.o src/bin/pg_dump/pg_dump.p/pg_dump.c.o src/bin/pg_dump/pg_dump.p/pg_dump_sort.c.o -Wl,--as-needed -Wl,--no-undefined '-Wl,-rpath,$ORIGIN/../../interfaces/libpq:XXXXXXX' -Wl,-rpath-link,/build/postgres-${POSTGRES_VERSION}/builddir/src/interfaces/libpq -Wl,--start-group src/bin/pg_dump/libpgdump_common.a src/fe_utils/libpgfeutils.a src/common/libpgcommon.a src/common/libpgcommon_ryu.a src/common/libpgcommon_config_info.a src/port/libpgport.a src/port/libpgport_crc.a src/interfaces/libpq/libpq.a -static -lm -lssl -lcrypto -Wl,--end-group

# build psl with openssl / ligpq static
RUN cd builddir && cc  -o /tmp/psql src/bin/psql/psql.p/meson-generated_.._psqlscanslash.c.o src/bin/psql/psql.p/meson-generated_.._sql_help.c.o src/bin/psql/psql.p/command.c.o src/bin/psql/psql.p/common.c.o src/bin/psql/psql.p/copy.c.o src/bin/psql/psql.p/crosstabview.c.o src/bin/psql/psql.p/describe.c.o src/bin/psql/psql.p/help.c.o src/bin/psql/psql.p/input.c.o src/bin/psql/psql.p/large_obj.c.o src/bin/psql/psql.p/mainloop.c.o src/bin/psql/psql.p/prompt.c.o src/bin/psql/psql.p/startup.c.o src/bin/psql/psql.p/stringutils.c.o src/bin/psql/psql.p/tab-complete.c.o src/bin/psql/psql.p/variables.c.o -Wl,--as-needed -Wl,--no-undefined '-Wl,-rpath,$ORIGIN/../../interfaces/libpq:XXXXXXX' -Wl,-rpath-link,/build/postgres-${POSTGRES_VERSION}/builddir/src/interfaces/libpq -Wl,--start-group src/interfaces/libpq/libpq.a src/fe_utils/libpgfeutils.a src/common/libpgcommon.a src/common/libpgcommon_ryu.a src/common/libpgcommon_config_info.a src/port/libpgport.a src/port/libpgport_crc.a -Wl,-Bstatic -lssl -lcrypto -lssl -lcrypto -Wl,-Bdynamic -lm -Wl,--end-group
# uncomment to build completely static
# RUN cd builddir && cc  -o /tmp/psql src/bin/psql/psql.p/meson-generated_.._psqlscanslash.c.o src/bin/psql/psql.p/meson-generated_.._sql_help.c.o src/bin/psql/psql.p/command.c.o src/bin/psql/psql.p/common.c.o src/bin/psql/psql.p/copy.c.o src/bin/psql/psql.p/crosstabview.c.o src/bin/psql/psql.p/describe.c.o src/bin/psql/psql.p/help.c.o src/bin/psql/psql.p/input.c.o src/bin/psql/psql.p/large_obj.c.o src/bin/psql/psql.p/mainloop.c.o src/bin/psql/psql.p/prompt.c.o src/bin/psql/psql.p/startup.c.o src/bin/psql/psql.p/stringutils.c.o src/bin/psql/psql.p/tab-complete.c.o src/bin/psql/psql.p/variables.c.o -Wl,--as-needed -Wl,--no-undefined '-Wl,-rpath,$ORIGIN/../../interfaces/libpq:XXXXXXX' -Wl,-rpath-link,/build/postgres-${POSTGRES_VERSION}/builddir/src/interfaces/libpq -Wl,--start-group src/interfaces/libpq/libpq.a src/fe_utils/libpgfeutils.a src/common/libpgcommon.a src/common/libpgcommon_ryu.a src/common/libpgcommon_config_info.a src/port/libpgport.a src/port/libpgport_crc.a -static -lssl -lcrypto -lssl -lcrypto -lm -Wl,--end-group



FROM scratch
COPY --from=builder /tmp/psql /tmp/pg_dump ./

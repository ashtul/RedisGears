# BUILD redisfab/redisgears-${OSNICK}:M.m.b-${ARCH}

# stretch|bionic|buster
ARG OSNICK=buster

# ARCH=x64|arm64v8|arm32v7
ARG ARCH=x64

#----------------------------------------------------------------------------------------------
# FROM redis:latest AS builder
FROM redisfab/redis-${ARCH}-${OSNICK}:5.0.5 AS builder


ADD . /build
WORKDIR /build

RUN ./deps/readies/bin/getpy2
RUN ./system-setup.py
RUN make fetch SHOW=1

ENV X_NPROC "cat /proc/cpuinfo|grep processor|wc -l"
RUN echo nproc=$(nproc); echo NPROC=$(eval "$X_NPROC")
RUN make all SHOW=1

#----------------------------------------------------------------------------------------------
# FROM redis:latest
FROM redisfab/redis-${ARCH}-${OSNICK}:5.0.5

ENV REDIS_MODULES /opt/redislabs/lib/modules

RUN mkdir -p $REDIS_MODULES/

COPY --from=builder /build/redisgears.so $REDIS_MODULES/
COPY --from=builder /build/artifacts/release/redisgears-dependencies.*.tgz /tmp/

RUN tar xzf /tmp/redisgears-dependencies.*.tgz -C /

CMD ["--loadmodule", "/opt/redislabs/lib/modules/redisgears.so", "PythonHomeDir", "/opt/redislabs/lib/modules/python3"]

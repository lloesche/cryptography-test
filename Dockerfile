FROM someengineering/resotopython:1.0.1 as build-env
ENV DEBIAN_FRONTEND=noninteractive
ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG SOURCE_COMMIT

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RUN echo "I am running on ${BUILDPLATFORM}, building for ${TARGETPLATFORM}"
# Install Build dependencies
RUN apt-get update
RUN apt-get -y dist-upgrade
RUN apt-get -y install apt-utils
RUN apt-get -y install \
        build-essential \
        git \
        curl \
        unzip \
        zlib1g-dev \
        libncurses5-dev \
        libgdbm-dev \
        libgdbm-compat-dev \
        libnss3-dev \
        libreadline-dev \
        libsqlite3-dev \
        tk-dev \
        lzma \
        lzma-dev \
        liblzma-dev \
        uuid-dev \
        libbz2-dev \
        rustc \
        shellcheck \
        findutils \
        libtool \
        automake \
        autoconf \
        libffi-dev \
        libssl-dev \
        cargo \
        linux-headers-generic

# Create CPython and PyPy venv
WORKDIR /usr/local
RUN /usr/local/python/bin/python3 -m venv resoto-venv-python3
RUN /usr/local/pypy/bin/pypy3 -m venv resoto-venv-pypy3

# Prepare PyPy whl build env
RUN mkdir -p /build-python
RUN mkdir -p /build-pypy

# Download and install Python test tools
RUN . /usr/local/resoto-venv-python3/bin/activate && python -m pip install -U pip wheel tox flake8
RUN . /usr/local/resoto-venv-pypy3/bin/activate && pypy3 -m pip install -U pip wheel

# Build resotolib
COPY cryptographytest /usr/src/cryptographytest
WORKDIR /usr/src/cryptographytest
RUN if [ "X${TESTS:-false}" = Xtrue ]; then . /usr/local/resoto-venv-python3/bin/activate && tox; fi
RUN . /usr/local/resoto-venv-python3/bin/activate && python -m pip wheel -w /build-python -f /build-python .
RUN . /usr/local/resoto-venv-pypy3/bin/activate && pypy3 -m pip wheel -w /build-pypy -f /build-pypy .

# Install all wheels
RUN . /usr/local/resoto-venv-python3/bin/activate && python -m pip install -f /build-python /build-python/*.whl
RUN . /usr/local/resoto-venv-pypy3/bin/activate && pypy3 -m pip install -f /build-pypy /build-pypy/*.whl

RUN echo "${SOURCE_COMMIT:-unknown}" > /usr/local/etc/git-commit.HEAD


# Setup main image
FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG="en_US.UTF-8"
COPY --from=build-env /usr/local /usr/local
ENV PATH=/usr/local/python/bin:/usr/local/pypy/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
WORKDIR /
RUN apt-get update \
    && apt-get -y --no-install-recommends install apt-utils \
    && apt-get -y dist-upgrade \
    && apt-get -y --no-install-recommends install \
        dumb-init \
        iproute2 \
        dnsmasq \
        libffi7 \
        openssl \
        procps \
        dateutils \
        curl \
        jq \
        cron \
        ca-certificates \
        openssh-client \
        locales \
        unzip \
        nano \
        nvi \
    && echo 'LANG="en_US.UTF-8"' > /etc/default/locale \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && rm -f /bin/sh \
    && ln -s /bin/bash /bin/sh \
    && locale-gen \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENTRYPOINT ["/bin/dumb-init", "--"]
CMD ["/bin/bash"]

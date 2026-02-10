# =============================================================================
# Stage 1: Build - Compile Perl and install CPAN modules
# =============================================================================
FROM debian:bullseye-slim AS builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG PERL_VERSION=5.32.1

ENV DEBIAN_FRONTEND=noninteractive

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    ca-certificates \
    patch \
    bzip2 \
    # DBD::mysql
    default-libmysqlclient-dev \
    # Imager
    libjpeg-dev \
    libpng-dev \
    libgif-dev \
    libfreetype-dev \
    libtiff-dev \
    # XML::Parser, XML::SAX::ExpatXS, XML::SAX::Expat
    libexpat1-dev \
    # XML::LibXML::SAX
    libxml2-dev \
    # Net::SSLeay, IO::Socket::SSL
    libssl-dev \
    # Crypt::DSA (Math::BigInt::GMP)
    libgmp-dev \
    # YAML::Syck
    libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

# Install perlbrew
ENV PERLBREW_ROOT=/opt/perlbrew
RUN curl -L https://install.perlbrew.pl | bash
ENV PATH="${PERLBREW_ROOT}/bin:${PATH}"

# Compile Perl
RUN perlbrew install "perl-${PERL_VERSION}" \
    --as "perl-${PERL_VERSION}" \
    -Dusethreads \
    -Duseshrplib \
    -j"$(nproc)" \
    --notest

# Set up compiled Perl
ENV PERL_HOME="${PERLBREW_ROOT}/perls/perl-${PERL_VERSION}"
ENV PATH="${PERL_HOME}/bin:${PATH}"

# Install cpanm (copy to PERL_HOME/bin so it's available in runtime stage)
RUN perlbrew install-cpanm \
    && cp "${PERLBREW_ROOT}/bin/cpanm" "${PERL_HOME}/bin/cpanm"

# Install cpm (fast parallel CPAN installer) and Carton::Snapshot (for cpanfile.snapshot support)
RUN cpanm --notest App::cpm Carton::Snapshot \
    && rm -rf /root/.cpanm/work /root/.cpanm/build.log

# Install CPAN modules from cpanfile + snapshot for reproducibility
WORKDIR /build
COPY common/cpanfile common/cpanfile.snapshot /build/
RUN cpm install --global --show-build-log-on-failure \
    && rm -rf /root/.perl-cpm

# =============================================================================
# Stage 2: Runtime - Minimal image with compiled Perl
# =============================================================================
FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    # DBD::mysql runtime
    libmariadb3 \
    # Imager runtime
    libjpeg62-turbo \
    libpng16-16 \
    libgif7 \
    libfreetype6 \
    libtiff5 \
    # XML modules runtime
    libexpat1 \
    libxml2 \
    # SSL runtime
    libssl1.1 \
    # GMP runtime
    libgmp10 \
    # YAML::Syck runtime
    libyaml-0-2 \
    # Development utilities
    procps \
    && rm -rf /var/lib/apt/lists/*

# Copy compiled Perl from builder
ARG PERL_VERSION=5.32.1
ENV PERLBREW_ROOT=/opt/perlbrew
ENV PERL_HOME="${PERLBREW_ROOT}/perls/perl-${PERL_VERSION}"
COPY --from=builder "${PERLBREW_ROOT}/perls/perl-${PERL_VERSION}" "${PERLBREW_ROOT}/perls/perl-${PERL_VERSION}"

# Set up PATH
ENV PATH="${PERL_HOME}/bin:${PATH}"
ENV PERL5LIB="/app/movabletype/lib:/app/movabletype/extlib:${PERL_HOME}/lib/${PERL_VERSION}"

# Copy Procfile
COPY common/Procfile /etc/proclet/Procfile

# Copy entrypoint
COPY common/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Copy application
COPY app/ /app/

WORKDIR /app/movabletype

EXPOSE 5000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

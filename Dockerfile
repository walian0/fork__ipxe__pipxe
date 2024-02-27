

## docker  build  -f Dockerfile  .  -t ipxe_pipxe_localbuild  --output "./" --target copytohost
## docker  build  -f Dockerfile  .  -v $(pwd):/opt/thisrepo  -t ipxe_pipxe_localbuild  --output "./" --target copytohost

## docker via podman
## docker  --cgroup-manager cgroupfs  build  -f Dockerfile  .  -t ipxe_pipxe_localbuild  --output "./" --target copytohost





FROM ubuntu:22.04 as runner

RUN \
  apt update && \
  DEBIAN_FRONTEND=noninteractive  apt install -y --no-install-recommends \
    binutils \
    ca-certificates \
    gcc \
    g++ \
    git \
    make \
    python-is-python3 \
    python3

RUN \
  apt clean




## mtools hack (for ubuntu 22.04)
ENV MTOOLS_UBUNTU_RELEASE_NAME=noble
RUN \
  cat <<EOFF > /etc/apt/apt.conf.d/01-default-release
APT
{
  Default-Release "jammy";
};
EOFF
RUN \
  cat <<EOFF >> /etc/apt/sources.list
## hack for mtools
deb http://security.ubuntu.com/ubuntu ${MTOOLS_UBUNTU_RELEASE_NAME} main
EOFF
RUN \
  cat <<EOFF >> /etc/apt/preferences.d/01-mtools
Package: mtools
Pin: release n=${MTOOLS_UBUNTU_RELEASE_NAME}
Pin-Priority: 995
EOFF



## install packages
RUN apt update
RUN apt install -y -o Acquire::Retries=50 \
  gcc-aarch64-linux-gnu iasl mtools \
  lzma-dev uuid-dev zip

## python hack (for ubuntu 22.04 and older git-module codebase): ensure python exists in PATH (as symlink to python3)
#RUN ln -sf $(which python3)  $(which python3 | sed 's/3//g')




FROM runner as builder




## copy in repo
## improve? with mounting $(pwd):/opt/thisrepo
COPY . /opt/thisrepo




WORKDIR /opt/thisrepo




## run make: Sources (git)
RUN \
  make submodules

## run make: Sources (git sparce-checkout)
RUN \
  make firmware




FROM builder as build




## run make: Build (EFI)
RUN \
  make efi -e RPI_MAJ_VER=3

## run make: Build (iPXE)
RUN \
  make ipxe -j 4 -e RPI_MAJ_VER=3

## run make: SD card (rpi3)
RUN \
  make -e RPI_MAJ_VER=3

## run make: SD card (rpi4)
RUN \
  make -e RPI_MAJ_VER=4

RUN \
  chmod 666 sdcard_rpi*.*


FROM scratch as copytohost


COPY --link --from=build /opt/thisrepo/sdcard_rpi3.zip /outs/sdcard_rpi3.img
COPY --link --from=build /opt/thisrepo/sdcard_rpi3.zip /outs/sdcard_rpi3.zip

COPY --link --from=build /opt/thisrepo/sdcard_rpi4.zip /outs/sdcard_rpi4.img
COPY --link --from=build /opt/thisrepo/sdcard_rpi4.zip /outs/sdcard_rpi4.zip

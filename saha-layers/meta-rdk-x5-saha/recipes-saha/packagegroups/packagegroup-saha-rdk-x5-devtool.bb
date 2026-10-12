DESCRIPTION = "On-target development tools packagegroup for Saha RDK X5 board images"
LICENSE = "MIT"

inherit packagegroup

# Target rustc/cargo plus the host-side deps needed for board-side cargo builds
# (e.g. dora e2e). perl is required by openssl-sys Configure; buildessential
# provides gcc/g++/make/pkgconfig; openssl-dev avoids rebuilding OpenSSL from
# crates when pkg-config can find the system library.
RDEPENDS:${PN} = " \
    rust \
    cargo \
    packagegroup-core-buildessential \
    perl \
    openssl \
    openssl-dev \
    pkgconfig \
    cmake \
    git \
"

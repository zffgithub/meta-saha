SUMMARY = "Pinned dora-rs CLI for RDK X5 dataflow runtime"
HOMEPAGE = "https://github.com/dora-rs/dora"
DESCRIPTION = "Official aarch64-unknown-linux-gnu dora CLI release used by \
packagegroup-saha-rdk-x5-dora. The binary is the coordinator/CLI entry point \
(dora); node APIs remain available through language packages installed later."
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://LICENSE;md5=48d0251b33ff53c123e3eb6d5dc6fdc8"

SRC_URI = " \
    https://github.com/dora-rs/dora/releases/download/v${PV}/dora-cli-aarch64-unknown-linux-gnu.tar.gz \
    https://raw.githubusercontent.com/dora-rs/dora/v${PV}/LICENSE;name=license;downloadfilename=LICENSE \
"
SRC_URI[sha256sum] = "77fe85ff1eaf2cac2bf9e0d46d1efe00cad5076b5a0cf4e42b2cf2c646b4752f"
SRC_URI[license.sha256sum] = "7b515bc646ca4e20427bc6a72b8ca5149a0e9b38a77e9a7d0ba5463af5a6cfbc"

S = "${UNPACKDIR}/dora-cli-aarch64-unknown-linux-gnu"

inherit bin_package

COMPATIBLE_HOST = "aarch64.*-linux"
PACKAGE_ARCH = "${TUNE_PKGARCH}"
RDEPENDS:${PN} = "libgcc"
INSANE_SKIP:${PN} += "already-stripped ldflags"

do_unpack:append() {
    cp -f ${UNPACKDIR}/LICENSE ${S}/LICENSE
}

do_install() {
    install -d ${D}${bindir} ${D}${datadir}/licenses/${PN}
    install -m 0755 ${S}/dora ${D}${bindir}/dora
    install -m 0644 ${S}/LICENSE ${D}${datadir}/licenses/${PN}/LICENSE
}

FILES:${PN} = "${bindir}/dora ${datadir}/licenses/${PN}"
FILES:${PN}-dev = ""

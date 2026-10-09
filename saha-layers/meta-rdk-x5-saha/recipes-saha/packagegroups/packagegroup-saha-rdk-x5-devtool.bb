DESCRIPTION = "On-target development tools packagegroup for Saha RDK X5 board images"
LICENSE = "MIT"

inherit packagegroup

# Target rustc/cargo from OE-Core (same set as packagegroup-rust-sdk-target).
# Intended for board-side cargo builds such as dora e2e; not for SDK nativesdk.
RDEPENDS:${PN} = " \
    rust \
    cargo \
"

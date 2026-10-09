DESCRIPTION = "dora-rs runtime packagegroup for Saha RDK X5 images"
LICENSE = "MIT"

inherit packagegroup

# Base RDK X5 images use dora-rs instead of ROS 2. Start with the pinned CLI
# binary; language APIs (Python/Rust crates) can extend this packagegroup later.
RDEPENDS:${PN} = " \
    dora-cli \
"

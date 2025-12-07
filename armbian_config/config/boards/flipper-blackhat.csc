# Allwinner A33 quad core 512MB SoC module
BOARD_NAME="Flipper Blackhat"
BOARDFAMILY="sun8i"
BOARD_MAINTAINER=""
HAS_VIDEO_OUTPUT="no"

# U-Boot
BOOTCONFIG="flipper_blackhat_defconfig"

# Kernel DTB that should be used by default
BOOT_FDT_FILE="sun8i-a33-flipper-blackhat.dtb"

# Device-tree overlay prefix for this SoC family
OVERLAY_PREFIX="sun8i-a33"

# Kernel flavours to build
KERNEL_TARGET="current,edge,legacy"
KERNEL_TEST_TARGET="current"

# --- Enable Raspberry-Pi-style dual partition layout ---

BOOTFS_TYPE="fat"
BOOTSIZE="256"
BOOTFS_LABEL="BOOT"

ROOTFS_TYPE="ext4"
ROOTFS_LABEL="ROOTFS"

IMAGE_PARTITION_TABLE_TYPE="dos"

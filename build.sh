#!/bin/bash
CYANOGENMOD=`pwd`/../../..

# toolchain
CROSS_COMPILE="/home/nics/gcc/arm-eabi-4.4.3/bin/arm-eabi-"

# defconfig
KERNEL_DEFCONFIG=latona_defconfig

# output directory
KERNEL_OUT="/home/nics/CYANOGENMOD/device/samsung/galaxysl/kernel/"

# board config
BOARD_KERNEL_PAGESIZE=4096
BOARD_KERNEL_CMDLINE="console=ttySAC2,115200 consoleblank=0"
BOARD_KERNEL_BASE=0x10000000

# mkbootimg path
MKBOOTIMG="/home/nics/tools/mkbootimg"

# ramdisk compression: gz, lzma, bz2|bzip2, xz
COMPRESSION=gz


######

export CROSS_COMPILE=$CROSS_COMPILE
export ARCH=arm

txtrst='\e[0m'     # Color off
txtred='\e[0;31m'  # Red
txtbred='\e[1;31m' # Bold red
txtblue='\e[0;34m' # Blue

THREADS=`cat /proc/cpuinfo | grep processor | wc -l`

exit_status() {
    if [ $1 -ne 0 ]; then
        echo -e "${txtbred}Error${txtrst}"
        exit 1
    fi
}

# clean out dir
mkdir -p /home/nics/CYANOGENMOD/device/samsung/galaxysl/kernel/modules

# make defconfig
make -j$THREADS $KERNEL_DEFCONFIG
exit_status $?

#fix build without changing defconfig
sed -i 's:source/usr/latona_initramfs.list:usr/latona_initramfs.list:g' .config

# make modules
echo -e "\n${txtred}Building modules...${txtrst}"
nice -n 10 make -j$THREADS modules
exit_status $?
find -name '*.ko' -exec cp -av {} /home/nics/CYANOGENMOD/device/samsung/galaxysl/kernel/modules \;

# build kernel
echo -e "\n${txtred}Building kernel...${txtrst}"
nice -n 10 make -j$THREADS zImage
exit_status $?
cp arch/arm/boot/zImage /home/nics/CYANOGENMOD/device/samsung/galaxysl/kernel/zImage

# make ramdisk
echo -e "\n${txtred}Making ramdisk...${txtrst}"
case $COMPRESSION in
    lzma) ext="lzma"; cmd="lzma -v";;
    bz2|bzip2) ext="bz2"; cmd="bzip2 -v";;
    xz) ext="xz"; cmd="xz -v";;
    *) ext="gz"; cmd="gzip";;
esac

cd usr/ramdisk
cd android
chmod 0644 *.rc default.prop
find . | cpio -o -H newc | gzip > ../bootstrap/ramdisk.cpio.gz
cd ..

cd recovery
chmod 0644 *.rc default.prop
find . | cpio -o -H newc | gzip > ../bootstrap/ramdisk-recovery.cpio.gz
cd ..

cd bootstrap
find . | cpio -o -H newc | $cmd > $KERNEL_OUT/ramdisk.cpio.$ext
rm -f ramdisk.cpio.gz
rm -f ramdisk-recovery.cpio.gz
cd ..

# make boot.img
cd $KERNEL_OUT
echo -e "\n${txtred}Making boot.img...${txtrst}"
if [ ! -f $MKBOOTIMG ]; then
    echo -e "${txtbred}Error: mkbootimg not found${txtrst}"
    exit 1
fi
$MKBOOTIMG --kernel zImage --ramdisk ramdisk.cpio.$ext --cmdline "$BOARD_KERNEL_CMDLINE" --base "$BOARD_KERNEL_BASE" --pagesize "$BOARD_KERNEL_PAGESIZE" -o boot.img
exit_status $?

# clean
rm -f ramdisk.cpio.*

# strip modules
echo -e "\n${txtred}Stripping modules...${txtrst}"
cd modules
find -name '*.ko' -exec ${CROSS_COMPILE}strip --strip-unneeded {} \;

echo -e "\nDone: ${txtblue}`readlink -f ${KERNEL_OUT}/boot.img`${txtrst}"

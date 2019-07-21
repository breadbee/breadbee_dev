.PHONY: linux upload

BUILDROOT=$(shell realpath ../breadbee_buildroot/buildroot)
CROSS_COMPILE=arm-buildroot-linux-gnueabihf-

all: upload nor_ipl

bootstrap:
	git clone git@github.com:fifteenhex/linux.git
	git -C linux checkout -b msc313e
	git clone git@github.com:fifteenhex/u-boot.git
	git -C u-boot checkout -b msc313

linux:
	- rm linux/arch/arm/boot/zImage
	PATH=$(BUILDROOT)/output/host/bin:$$PATH $(MAKE) -C linux DTC_FLAGS=--symbols ARCH=arm -j8 CROSS_COMPILE=$(CROSS_COMPILE) zImage dtbs
	# these are for booting with the old mstar u-boot that can't load a dtb
	cat linux/arch/arm/boot/zImage linux/arch/arm/boot/dts/msc313e-breadbee.dtb >\
		linux/arch/arm/boot/zImage.msc313e
	cat linux/arch/arm/boot/zImage linux/arch/arm/boot/dts/msc313d-mc400l.dtb >\
		linux/arch/arm/boot/zImage.msc313d

linux_config:
	$(MAKE) -C linux ARCH=arm -j8 CROSS_COMPILE=arm-linux-gnueabihf- menuconfig

linux_clean:
	$(MAKE) -C linux ARCH=arm -j8 CROSS_COMPILE=arm-linux-gnueabihf- clean

uboot:
	$(MAKE) -C u-boot msc313_breadbee_defconfig
	$(MAKE) -C u-boot CROSS_COMPILE=arm-linux-gnueabihf- -j12


# this is to upload the resulting binaries to a tftp server to load on the
# target
upload: linux uboot kernel.fit
	scp linux/arch/arm/boot/zImage.msc313e tftp:/srv/tftp/zImage.msc313e
	scp linux/arch/arm/boot/dts/msc313e-breadbee.dtb tftp:/srv/tftp/msc313e-breadbee.dtb
	scp u-boot/spl/u-boot-spl.bin tftp:/srv/tftp/ubootspl.msc313e
	scp u-boot/u-boot.img tftp:/srv/tftp/uboot.msc313e
	scp kernel.fit tftp:/srv/tftp/kernel.fit.breadbee
#	scp linux/arch/arm/boot/zImage.msc313d tftp:/srv/tftp/zImage.msc313d
#	scp buildroot/output/images/rootfs.squashfs tftp:/srv/tftp/rootfs.msc313e


# this is a nor sized image (because flashrom doesn't support writing partial images)
# that starts with the mstar IPL
nor_ipl: uboot kernel.fit
	rm -f nor_ipl
	dd if=/dev/zero ibs=1M count=16 | tr "\000" "\377" > nor_ipl
	dd conv=notrunc if=IPL.bin of=nor_ipl bs=1k seek=16
	dd conv=notrunc if=u-boot/spl/u-boot-spl.bin of=nor_ipl bs=1k seek=64
	dd conv=notrunc if=u-boot/u-boot.img of=nor_ipl bs=1k seek=128
	dd conv=notrunc if=kernel.fit of=nor_ipl bs=1k seek=512

# this is a nor sized image that starts with the u-boot SPL. This will require the
# SPL do the DDR setup etc.
nor: uboot kernel.fit
	rm -f nor
	dd if=/dev/zero ibs=1M count=16 | tr "\000" "\377" > nor
	dd conv=notrunc if=u-boot/spl/u-boot-spl.bin of=nor bs=1k seek=16
	dd conv=notrunc if=u-boot/u-boot.img of=nor bs=1k seek=128

# this builds a FIT image with the kernel and the right device trees. This
# should be used with the new u-boot.
kernel.fit: linux
	mkimage -f kernel.its kernel.fit

clean: linux_clean
	rm -rf kernel.fit nor nor_ipl

push_linux_config:
	cp linux/.config ../breadbee_buildroot/br2breadbee/board/thingyjp/breadbee/linux.config

fix_brick:
	flashrom --programmer ch341a_spi -w nor_ipl -l /media/junk/hardware/breadbee/flashrom_layout -i ipl_uboot_spl -N

buildroot:
	$(MAKE) -C ../breadbee_buildroot

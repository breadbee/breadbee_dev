# Note: This isn't really a build system
# It's a bunch of command lines encoded
# in a Makefile so I don't have to remember
# multi part processes

BBBUILDROOT=$(shell realpath ./bbbuildroot)
M5BUILDROOT=$(shell realpath ./m5buildroot)
OUTPUTS=$(shell realpath ./outputs/)
BUILDROOT=$(BBBUILDROOT)/buildroot

.PHONY: toolchain \
	buildroot_bb \
	buildroot_m5 \
	uboot_bb \
	uboot_m5 \
	linux \
	upload \
	outputsdir \
	kernel_m5.fit \
	kernel_breadbee.fit \
	rtk \
	squeekyclean \
	nor_ipl \
	patchpushpreflight

CROSS_COMPILE=arm-buildroot-linux-gnueabihf-

all: toolchain nor_ipl spl_padded

outputsdir:
	mkdir -p $(OUTPUTS)

# We have two copies of build root here:
# one is the breadbee version with the bits it needs
# the other is the m5 version that is basically stock.

buildroot_bb:
	$(MAKE) -C $(BBBUILDROOT)

buildroot_bb_clean:
	$(MAKE) -C $(BBBUILDROOT) clean

buildroot_m5:
	$(MAKE) -C $(M5BUILDROOT)
	# We might want a generic rootfs to embed into a kernel,
	# so copy that into the outputs dir
	cp $(M5BUILDROOT)/buildroot/output/images/rootfs.cpio $(OUTPUTS)/m5_rootfs.cpio

buildroot_m5_config:
	$(MAKE) -C $(M5BUILDROOT) buildroot_config

buildroot_m5_linux_config:
	$(MAKE) -C $(M5BUILDROOT) buildroot_linux_menuconfig

buildroot_m5_linux_update:
	$(MAKE) -C $(M5BUILDROOT) linux_update
	$(MAKE) -C $(M5BUILDROOT) linux_clean

buildroot_m5_clean:
	$(MAKE) -C $(M5BUILDROOT) clean

toolchain:
	if [ ! -e $(BUILDROOT)/output/host/bin/arm-buildroot-linux-gnueabihf-gcc ]; then \
		$(MAKE) buildroot; \
	fi

DEFAULT_BRANCH_LINUX=mstar_dev_v5_8_rebase_cleanup
DEFAULT_BRANCH_UBOOT=m5iplwork

bootstrap:
	git clone git@github.com:fifteenhex/linux.git
	git -C linux checkout --track origin/$(DEFAULT_BRANCH_LINUX)
	cp linux.config linux/.config
	git clone git@github.com:breadbee/u-boot.git
	git -C u-boot checkout --track origin/$(DEFAULT_BRANCH_UBOOT)
	git clone git@github.com:breadbee/breadbee_buildroot.git $(BBBUILDROOT)
	$(MAKE) -C $(BBBUILDROOT) bootstrap
	git clone git@github.com:fifteenhex/mstarblobs.git

	git clone git@github.com:fifteenhex/buildroot_mercury5.git $(M5BUILDROOT)
	$(MAKE) -C $(M5BUILDROOT) bootstrap

LINUX_ARGS=ARCH=arm -j8 CROSS_COMPILE=$(CROSS_COMPILE)
linux:
	- rm linux/arch/arm/boot/zImage
	PATH=$(BUILDROOT)/output/host/bin:$$PATH \
		$(MAKE) -C linux DTC_FLAGS=--symbols \
		$(LINUX_ARGS) \
		zImage dtbs
	# these are for booting with the old mstar u-boot that can't load a dtb
	#cat linux/arch/arm/boot/zImage linux/arch/arm/boot/dts/msc313d-mc400l.dtb > \
	#	$(OUTPUTS)/zImage.msc313d

linux_config:
	PATH=$(BUILDROOT)/output/host/bin:$$PATH \
		$(MAKE) -C linux $(LINUX_ARGS) menuconfig

linux_clean:
	PATH=$(BUILDROOT)/output/host/bin:$$PATH \
		$(MAKE) -C linux $(LINUX_ARGS) clean

UBOOT_BB=$(OUTPUTS)/dev_u-boot_breadbee.img
IPL_BB=$(OUTPUTS)/dev_ipl_breadbee

uboot_bb: toolchain outputsdir
	$(MAKE) -C u-boot clean
	PATH=$(BUILDROOT)/output/host/bin:$$PATH \
		$(MAKE) -C u-boot msc313_breadbee_defconfig
	PATH=$(BUILDROOT)/output/host/bin:$$PATH \
		$(MAKE) -C u-boot CROSS_COMPILE=$(CROSS_COMPILE) -j8
	cp u-boot/u-boot.img $(UBOOT_BB)
	cp u-boot/ipl $(IPL_BB)

UBOOT_M5=$(OUTPUTS)/dev_u-boot_m5.img
IPL_M5=$(OUTPUTS)/dev_ipl_m5

uboot_m5: toolchain outputsdir
	$(MAKE) -C u-boot clean
	PATH=$(BUILDROOT)/output/host/bin:$$PATH \
		$(MAKE) -C u-boot mercury5_defconfig
	PATH=$(BUILDROOT)/output/host/bin:$$PATH \
		$(MAKE) -C u-boot CROSS_COMPILE=$(CROSS_COMPILE) -j8
	cp u-boot/u-boot.img $(UBOOT_M5)
	cp u-boot/ipl $(IPL_M5)

uboot_clean:
	PATH=$(BUILDROOT)/output/host/bin:$$PATH \
		$(MAKE) -C u-boot clean

# this is to upload the resulting binaries to a tftp server to load on the
# target
upload: linux uboot_bb kernel_breadbee.fit
	scp outputs/dev_kernel_breadbee.fit tftp:/srv/tftp/dev_kernel_breadbee.fit
#	scp linux/arch/arm/boot/zImage.msc313e tftp:/srv/tftp/zImage.msc313e
#	scp linux/arch/arm/boot/dts/infinity3-msc313e-breadbee.dtb tftp:/srv/tftp/msc313e-breadbee.dtb
#	scp u-boot/spl/u-boot-spl.bin tftp:/srv/tftp/ubootspl.msc313e
#	scp u-boot/u-boot.img tftp:/srv/tftp/uboot.msc313e
#	scp kernel.fit tftp:/srv/tftp/kernel.fit.breadbee
#	scp linux/arch/arm/boot/zImage.msc313d tftp:/srv/tftp/zImage.msc313d
#	scp buildroot/output/images/rootfs.squashfs tftp:/srv/tftp/rootfs.msc313e

# this is a nor sized image (because flashrom doesn't support writing partial images)
# that starts with the mstar IPL
nor_ipl: uboot_bb kernel_breadbee.fit
	rm -f nor_ipl
	dd if=/dev/zero ibs=1M count=16 | tr "\000" "\377" > nor_ipl
	##dd conv=notrunc if=IPL.bin of=nor_ipl bs=1k seek=16
	dd conv=notrunc if=mstarblobs/ipl_ddr3.bin of=nor_ipl bs=1k seek=16
	dd conv=notrunc if=$(IPL_BB) of=nor_ipl bs=1k seek=64
	dd conv=notrunc if=$(UBOOT_BB) of=nor_ipl bs=1k seek=128
	dd conv=notrunc if=$(OUTPUTS)/dev_kernel_breadbee.fit of=nor_ipl bs=1k seek=512
	mv nor_ipl $(OUTPUTS)/nor_ipl

# this is a nor sized image that starts with the u-boot SPL. This will require the
# SPL do the DDR setup etc.
nor: uboot_bb
	rm -f nor
	dd if=/dev/zero ibs=1M count=16 | tr "\000" "\377" > nor
	dd conv=notrunc if=u-boot/spl/u-boot-spl.bin of=nor bs=1k seek=16
	dd conv=notrunc if=u-boot/u-boot.img of=nor bs=1k seek=128

# This builds a FIT image with the kernel and right device tree for m5
kernel_m5.fit: buildroot_m5 outputsdir linux
	mkimage -f kernel_m5.its \
		$(OUTPUTS)/dev_$@

# This builds a FIT image with the kernel and the right device trees for breadbee.
kernel_breadbee.fit: outputsdir linux
	mkimage -f kernel_breadbee.its \
		$(OUTPUTS)/dev_$@

# This builds kernel image with the DTB appended to the end for the ssd201htv2 with
# vendor u-boot
kernel_ssd201htv2: outputsdir linux buildroot_m5
	cat linux/arch/arm/boot/zImage linux/arch/arm/boot/dts/infinity2m-ssd202-ssd201htv2.dtb > \
		$(OUTPUTS)/$@

# This builds kernel image with the DTB appended to the end for the mcf50 with
# vendor u-boot
kernel_mcf50: outputsdir linux buildroot_m5
	cat linux/arch/arm/boot/zImage linux/arch/arm/boot/dts/infinity6b0-ssc337de-mcf50.dtb > \
		$(OUTPUTS)/$@

clean: linux_clean
	rm -rf kernel_m5.fit kernel_breadbee.fit nor nor_ipl

push_linux_config:
	cp linux/.config ../breadbee_buildroot/br2breadbee/board/thingyjp/breadbee/linux.config

push_linux_m5_config:
	PATH=$(BUILDROOT)/output/host/bin:$$PATH \
		$(MAKE) -C linux DTC_FLAGS=--symbols \
		ARCH=arm -j8 CROSS_COMPILE=$(CROSS_COMPILE) savedefconfig
	cp linux/defconfig $(M5BUILDROOT)/br2midrive08/board/70mai/midrive08/linux.config

fix_brick: nor_ipl
	sudo flashrom --programmer ch341a_spi -w $(OUTPUTS)/nor_ipl \
		-l /media/junk/hardware/breadbee/flashrom_layout -i ipl_uboot_spl -N
	sudo flashrom --programmer ch341a_spi -w $(OUTPUTS)/nor_ipl \
		-l /media/junk/hardware/breadbee/flashrom_layout -i uboot -N

fix_brick_spl:
	sudo flashrom --programmer ch341a_spi -w nor -l /media/junk/hardware/breadbee/flashrom_layout -i ipl_uboot_spl -N
	sudo flashrom --programmer ch341a_spi -w nor -l /media/junk/hardware/breadbee/flashrom_layout -i uboot -N

rtk: uboot_m5
	cp u-boot/u-boot.bin $(OUTPUTS)/rtk

squeekyclean:
	$(MAKE) -C $(BBBUILDROOT) clean

copy_kernel_to_sd: kernel_m5.fit
	sudo mount /dev/sdc1 /mnt
	- sudo cp outputs/dev_kernel_m5.fit /mnt/kernel.fit
	sudo umount /mnt

copy_spl_m5_to_sd: uboot_m5
	sudo mount /dev/sdc1 /mnt
	- sudo cp $(IPL_M5) /mnt/ipl
	sudo umount /mnt

copy_uboot_m5_to_sd: uboot_m5
	sudo mount /dev/sdc1 /mnt
	- sudo cp $(UBOOT_M5) /mnt/u-boot.img
	sudo umount /mnt

copy_rtk_m5_to_sd: rtk
	sudo mount /dev/sdc1 /mnt
	- sudo cp outputs/rtk /mnt/rtk
	sudo umount /mnt

run_tftpd: buildroot
	$(MAKE) -C $(BBBUILDROOT) run_tftpd

cleanuplinuxtree:
	git -C linux clean -fd


patchpushpreflight: cleanuplinuxtree kernel_m5.fit

checkdtbindings:
	PATH=~/.local/bin/:$(PATH) $(MAKE) -C linux dt_binding_check -j12

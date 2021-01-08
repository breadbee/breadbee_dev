# Note: This isn't really a build system
# It's a bunch of command lines encoded
# in a Makefile so I don't have to remember
# multi part processes

BBBUILDROOT=$(shell realpath ./bbbuildroot)
M5BUILDROOT=$(shell realpath ./m5buildroot)
BUILDROOT_GW30X=$(shell realpath ./buildroot_gw30x)

OUTPUTS=$(shell realpath ./outputs/)
BUILDROOT=$(BBBUILDROOT)/buildroot

.PHONY: toolchain \
	buildroot_bb \
	buildroot_m5 \
	buildroot-gw30x \
	uboot_bb \
	uboot-generic \
	uboot-gw302 \
	uboot_m5 \
	linux \
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

# Prepare the environment
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

# We need an ARM toolchain to build stuff so build one
# in the breadbee buildroot
toolchain:
	if [ ! -e $(BUILDROOT)/output/host/bin/arm-buildroot-linux-gnueabihf-gcc ]; then \
		$(MAKE) buildroot; \
	fi

# We have two copies of build root here:
# one is the breadbee version with the bits it needs
# the other is the m5 version that is basically stock.

buildroot_bb:
	$(MAKE) -C $(BBBUILDROOT)

buildroot_bb_clean:
	$(MAKE) -C $(BBBUILDROOT) clean

buildroot_bb_config:
	$(MAKE) -C $(BBBUILDROOT) buildroot_config

buildroot_bb_linux_update:
	$(MAKE) -C $(BBBUILDROOT) linux_update
	$(MAKE) -C $(BBBUILDROOT) linux_clean

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

buildroot-gw30x:
	$(MAKE) -C $(BUILDROOT_GW30X)

buildroot-menuconfig-gw30x:
	$(MAKE) -C $(BUILDROOT_GW30X) buildroot-menuconfig

LINUX_ARGS=ARCH=arm -j8 CROSS_COMPILE=$(CROSS_COMPILE) CONFIG_INITRAMFS_SOURCE=../outputs/m5_rootfs.cpio
linux:
	- rm linux/arch/arm/boot/zImage
	PATH=$(BUILDROOT)/output/host/bin:$$PATH \
		$(MAKE) -C linux DTC_FLAGS=--symbols \
		$(LINUX_ARGS) \
		zImage dtbs
	# these are for booting with the old mstar u-boot that can't load a dtb
	#cat linux/arch/arm/boot/zImage linux/arch/arm/boot/dts/msc313d-mc400l.dtb > \
	#	$(OUTPUTS)/zImage.msc313d

linux_internalinitramfs:
	- rm linux/arch/arm/boot/zImage
	PATH=$(BUILDROOT)/output/host/bin:$$PATH \
		$(MAKE) -C linux DTC_FLAGS=--symbols \
		$(LINUX_ARGS) \
		CONFIG_INITRAMFS_SOURCE=../outputs/m5_rootfs.cpio \
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

# uboot targets, only for breadbee and m5 for now

UBOOT_BB=$(OUTPUTS)/dev_u-boot_breadbee.img
IPL_BB=$(OUTPUTS)/dev_ipl_breadbee

uboot-generic: outputsdir
	$(MAKE) -C u-boot clean
	PATH=$(BUILDROOT)/output/host/bin:$$PATH \
		$(MAKE) -C u-boot mstarv7_defconfig
	PATH=$(BUILDROOT)/output/host/bin:$$PATH \
		$(MAKE) -C u-boot CROSS_COMPILE=$(CROSS_COMPILE) -j8
	cp u-boot/ipl $(OUTPUTS)/generic-ipl

uboot-gw302:
	$(MAKE) -C u-boot clean
	PATH=$(BUILDROOT)/output/host/bin:$$PATH \
		$(MAKE) -C u-boot mstar_infinity2m_gw302_defconfig
	PATH=$(BUILDROOT)/output/host/bin:$$PATH \
		$(MAKE) -C u-boot CROSS_COMPILE=$(CROSS_COMPILE) -j8
	cp u-boot/ipl $(OUTPUTS)/gw302-ipl

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
	$(BBBUILDROOT)/buildroot/output/host/bin/mkimage -f kernel_breadbee.its \
		$(OUTPUTS)/dev_$@
	chmod go+r $(OUTPUTS)/dev_$@

# This builds kernel image with the DTB appended to the end for the ssd201htv2 with
# vendor u-boot
kernel_ssd201htv2: outputsdir buildroot_m5 linux_internalinitramfs
	cat linux/arch/arm/boot/zImage linux/arch/arm/boot/dts/mstar-infinity2m-ssd202d-ssd201htv2.dtb > \
		$(OUTPUTS)/$@

# This builds a FIT image with the kernel and the right device trees for ssd20xd devices
kernel_ssd20xd.fit: outputsdir linux
	$(BBBUILDROOT)/buildroot/output/host/bin/mkimage -f kernel_ssd20xd.its \
		$(OUTPUTS)/dev_$@
	chmod go+r $(OUTPUTS)/dev_$@

# This builds kernel image with the DTB appended to the end for the gw302 with
# vendor u-boot
kernel_gw302: outputsdir buildroot_m5 linux_internalinitramfs
	cat linux/arch/arm/boot/zImage linux/arch/arm/boot/dts/mstar-infinity2m-ssd202d-gw302.dtb > \
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

run_tftpd: buildroot_bb
	$(MAKE) -C $(BBBUILDROOT) run_tftpd

cleanuplinuxtree:
	make -C linux clean
	git -C linux clean -fd

patchpushpreflight: cleanuplinuxtree linux

checkdtbindings:
	pip3 install git+https://github.com/devicetree-org/dt-schema.git@master
	PATH=~/.local/bin/:$(PATH) $(MAKE) -C linux clean
	PATH=~/.local/bin/:$(PATH) $(MAKE) -C linux dt_binding_check -j12

mainlining_generate_series:
	git -C linux format-patch --cover-letter -v2 torvalds/master


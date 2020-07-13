PWD = $(shell pwd)
OUTPUTS=$(shell realpath $(PWD)/outputs/)
LINUXROOT=$(shell realpath $(PWD)/linux)
LINUX_CONFIG=$(LINUXROOT)/.config
LINUX_IMAGE=$(LINUXROOT)/arch/arm/boot/zImage
UBOOTROOT=$(shell realpath $(PWD)/u-boot)
MSTARBLOBSROOT=$(shell realpath $(PWD)/mstarblobs)
VENDOR_FIT=$(OUTPUTS)/dev_vendor.fit
LINUX_ARGS=ARCH=arm -j8 CROSS_COMPILE=$(CROSS_COMPILE)

BBBUILDROOT=$(shell realpath $(PWD)/bbbuildroot)
BB_TOOLCHAIN=$(BBBUILDROOT)/buildroot/output/host
BB_UBOOT=$(OUTPUTS)/dev_u-boot.img
BB_SPL=$(OUTPUTS)/spl
BB_KERNEL=$(OUTPUTS)/dev_kernel_breadbee.fit

M5BUILDROOT=$(shell realpath $(PWD)/m5buildroot)
M5_TOOLCHAIN=$(M5BUILDROOT)/buildroot/output/host
M5_UBOOT=$(OUTPUTS)/dev_m5_u-boot.img
M5_SPL=$(OUTPUTS)/spl_m5
M5_KERNEL=$(OUTPUTS)/dev_kernel_m5.fit

M5_BOOTSTRAP_STAMP=.stamped_m5_bootstrap
BB_BOOTSTRAP_STAMP=.stamped_bb_boostrap

DEFAULT_BRANCH_LINUX=mstar_dev_v5_8_rebase_cleanup
DEFAULT_BRANCH_UBOOT=m5iplwork

M5_LINUX_STAMP=.stamped_m5_linux
BB_LINUX_STAMP=.stamped_bb_linux

OWNER=mbilloo

.PHONY: breadbee \
	m5 \
	squeakyclean \
	superclean

CROSS_COMPILE=arm-buildroot-linux-gnueabihf-

all: nor_ipl spl_padded

$(BBBUILDROOT):
	git clone git@github.com:$(OWNER)/breadbee_buildroot.git $(BBBUILDROOT)

$(BB_TOOLCHAIN): $(BBBUILDROOT) $(BB_BOOTSTRAP_STAMP)
	$(MAKE) -C $(BBBUILDROOT)

$(M5BUILDROOT):
	git clone git@github.com:$(OWNER)/buildroot_mercury5.git $(M5BUILDROOT)

$(M5_TOOLCHAIN): $(M5BUILDROOT) $(M5_BOOTSTRAP_STAMP)
	$(MAKE) -C $(M5BUILDROOT)

$(OUTPUTS):
	mkdir -p $(OUTPUTS)

$(MSTARBLOBSROOT):
	git clone git@github.com:fifteenhex/mstarblobs.git

DEFAULT_BRANCH_LINUX=mstar_dev_v5_8_rebase_cleanup
DEFAULT_BRANCH_UBOOT=m5iplwork

$(BB_BOOTSTRAP_STAMP): $(LINUXROOT) $(UBOOTROOT) $(BBBUILDROOT) $(MSTARBLOBSROOT) $(M5BUILDROOT)
	$(MAKE) -C $(BBBUILDROOT) bootstrap
	touch $@

$(M5_BOOTSTRAP_STAMP): $(M5STARBLOBSROOT) $(M5BUILDROOT)
	$(MAKE) -C $(M5BUILDROOT) bootstrap
	touch $@

$(UBOOTROOT):
	git clone git@github.com:breadbee/u-boot.git
	git -C u-boot checkout --track origin/$(DEFAULT_BRANCH_UBOOT)

$(LINUXROOT):
	git clone git@github.com:$(OWNER)/linux.git
	git -C linux checkout --track origin/$(DEFAULT_BRANCH_LINUX)

$(LINUX_CONFIG): $(LINUXROOT)
	cp linux.config $@

$(BB_LINUX_STAMP): $(BB_TOOLCHAIN) $(LINUX_CONFIG)
	PATH=$(BB_TOOLCHAIN)/bin:$$PATH \
		$(MAKE) -C linux DTC_FLAGS=--symbols \
		$(LINUX_ARGS) \
		zImage dtbs
	touch $@

$(M5_LINUX_STAMP): $(M5_TOOLCHAIN) $(LINUX_CONFIG)
	PATH=$(M5_TOOLCHAIN)/bin:$$PATH \
		$(MAKE) -C linux DTC_FLAGS=--symbols \
		$(LINUX_ARGS) \
		zImage dtbs
	# these are for booting with the old mstar u-boot that can't load a dtb
	#cat linux/arch/arm/boot/zImage linux/arch/arm/boot/dts/msc313d-mc400l.dtb > \
	#	$(OUTPUTS)/zImage.msc313d
	touch $@

linux_config:
	PATH=$(BUILDROOT)/output/host/bin:$$PATH \
		$(MAKE) -C linux $(LINUX_ARGS) menuconfig

linux_clean:
	PATH=$(BUILDROOT)/output/host/bin:$$PATH \
		$(MAKE) -C linux $(LINUX_ARGS) clean

$(BB_UBOOT): $(BB_TOOLCHAIN) $(OUTPUTS) $(UBOOTROOT)
	$(MAKE) -C u-boot clean
	PATH=$(BB_TOOLCHAIN)/bin:$$PATH \
		$(MAKE) -C u-boot msc313_breadbee_defconfig
	PATH=$(BB_TOOLCHAIN)/bin:$$PATH \
		$(MAKE) -C u-boot CROSS_COMPILE=$(CROSS_COMPILE)
	cp u-boot/u-boot.img $@

$(M5_UBOOT): $(M5_TOOLCHAIN) $(OUTPUTS) $(UBOOTROOT)
	$(MAKE) -C u-boot clean
	PATH=$(M5_TOOLCHAIN)/bin:$$PATH \
		$(MAKE) -C u-boot mercury5_defconfig
	PATH=$(M5_TOOLCHAIN)/bin:$$PATH \
		$(MAKE) -C u-boot CROSS_COMPILE=$(CROSS_COMPILE)
	cp u-boot/u-boot.img $@

uboot_clean: $(BB_TOOLCHAIN)
	PATH=$(BB_TOOLCHAIN)/bin:$$PATH \
		$(MAKE) -C u-boot clean

# this is to upload the resulting binaries to a tftp server to load on the
# target
upload: linux uboot kernel.fit
	scp outputs/dev_kernel_breadbee.fit tftp:/srv/tftp/dev_kernel_breadbee.fit
#	scp linux/arch/arm/boot/zImage.msc313e tftp:/srv/tftp/zImage.msc313e
#	scp linux/arch/arm/boot/dts/infinity3-msc313e-breadbee.dtb tftp:/srv/tftp/msc313e-breadbee.dtb
#	scp u-boot/spl/u-boot-spl.bin tftp:/srv/tftp/ubootspl.msc313e
#	scp u-boot/u-boot.img tftp:/srv/tftp/uboot.msc313e
#	scp kernel.fit tftp:/srv/tftp/kernel.fit.breadbee
#	scp linux/arch/arm/boot/zImage.msc313d tftp:/srv/tftp/zImage.msc313d
#	scp buildroot/output/images/rootfs.squashfs tftp:/srv/tftp/rootfs.msc313e


$(BB_SPL): $(BB_UBOOT)
	python3 u-boot/board/thingyjp/breadbee/fix_ipl_hdr.py \
		-i u-boot/spl/u-boot-spl.bin \
		-o $@

$(M5_SPL): $(M5_UBOOT)
	python3 u-boot/board/thingyjp/breadbee/fix_ipl_hdr.py \
		-i u-boot/spl/u-boot-spl.bin \
		-o $@

# this is a nor sized image (because flashrom doesn't support writing partial images)
# that starts with the mstar IPL
nor_ipl: uboot kernel.fit spl_padded
	rm -f nor_ipl
	dd if=/dev/zero ibs=1M count=16 | tr "\000" "\377" > nor_ipl
	##dd conv=notrunc if=IPL.bin of=nor_ipl bs=1k seek=16
	dd conv=notrunc if=ipl_ddr3.bin of=nor_ipl bs=1k seek=16
	dd conv=notrunc if=spl_padded of=nor_ipl bs=1k seek=64
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
$(M5_KERNEL): $(M5_TOOLCHAIN) $(OUTPUTS) $(M5_LINUX_STAMP)
	PATH=$(M5_TOOLCHAIN)/bin:$$PATH \
	mkimage -f kernel_m5.its $@

$(BB_KERNEL): $(BB_TOOLCHAIN) $(OUTPUTS) $(BB_LINUX_STAMP)
	PATH=$(BB_TOOLCHAIN)/bin:$$PATH \
	mkimage -f kernel_breadbee.its $@

$(VENDOR_FIT): $(OUTPUTS)
	mkimage -f vendor.its $@

kernel_ssd201htv2: $(OUTPUTS) $(LINUX_IMAGE)
	cat linux/arch/arm/boot/zImage linux/arch/arm/boot/dts/infinity2m-ssd202-ssd201htv2.dtb > \
		$(OUTPUTS)/$@

clean: linux_clean
	rm -rf kernel.fit nor nor_ipl

push_linux_config:
	cp linux/.config ../breadbee_buildroot/br2breadbee/board/thingyjp/breadbee/linux.config

fix_brick:
	sudo flashrom --programmer ch341a_spi -w nor_ipl -l /media/junk/hardware/breadbee/flashrom_layout -i ipl_uboot_spl -N
	sudo flashrom --programmer ch341a_spi -w nor_ipl -l /media/junk/hardware/breadbee/flashrom_layout -i uboot -N

fix_brick_spl:
	sudo flashrom --programmer ch341a_spi -w nor -l /media/junk/hardware/breadbee/flashrom_layout -i ipl_uboot_spl -N
	sudo flashrom --programmer ch341a_spi -w nor -l /media/junk/hardware/breadbee/flashrom_layout -i uboot -N

RTKPADBYTES=512

m5: $(M5_UBOOT) $(M5_SPL) $(M5_KERNEL)
	cp u-boot/u-boot.bin $(OUTPUTS)/rtk

breadbee: $(BB_UBOOT) $(BB_SPL) $(BB_KERNEL)

squeekyclean:
	$(MAKE) -C $(BBBUILDROOT) clean

superclean:
	git clean -fxd
	rm -fr $(BBBUILDROOT) $(M5BUILDROOT) $(LINUXROOT) $(UBOOTROOT) $(OUTPUTS) $(MSTARBLOBSROOT)

copy_kernel_to_sd: $(M5_KERNEL)
	sudo mount /dev/sdc1 /mnt
	- sudo cp outputs/dev_kernel_m5.fit /mnt/kernel.fit
	sudo umount /mnt

copy_spl_m5_to_sd: spl_m5
	sudo mount /dev/sdc1 /mnt
	- sudo cp outputs/spl_m5 /mnt/ipl
	sudo umount /mnt

copy_uboot_m5_to_sd: uboot_m5
	sudo mount /dev/sdc1 /mnt
	- sudo cp outputs/dev_m5_u-boot.img /mnt/u-boot.img
	sudo umount /mnt

copy_rtk_m5_to_sd: rtk
	sudo mount /dev/sdc1 /mnt
	- sudo cp outputs/rtk /mnt/rtk
	sudo umount /mnt

run_tftpd: buildroot
	$(MAKE) -C $(BBBUILDROOT) run_tftpd

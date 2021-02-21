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
	
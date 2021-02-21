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

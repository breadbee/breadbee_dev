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

fix_brick: nor_ipl
	sudo flashrom --programmer ch341a_spi -w $(OUTPUTS)/nor_ipl \
		-l /media/junk/hardware/breadbee/flashrom_layout -i ipl_uboot_spl -N
	sudo flashrom --programmer ch341a_spi -w $(OUTPUTS)/nor_ipl \
		-l /media/junk/hardware/breadbee/flashrom_layout -i uboot -N

fix_brick_spl:
	sudo flashrom --programmer ch341a_spi -w nor -l /media/junk/hardware/breadbee/flashrom_layout -i ipl_uboot_spl -N
	sudo flashrom --programmer ch341a_spi -w nor -l /media/junk/hardware/breadbee/flashrom_layout -i uboot -N

BUILDROOT_GW30X=$(shell realpath ./buildroot_gw30x)

buildroot-gw30x:
	$(MAKE) -C $(BUILDROOT_GW30X)

uboot-gw302:
	$(MAKE) -C u-boot clean
	PATH=$(BUILDROOT)/output/host/bin:$$PATH \
		$(MAKE) -C u-boot mstar_infinity2m_gw302_defconfig
	PATH=$(BUILDROOT)/output/host/bin:$$PATH \
		$(MAKE) -C u-boot CROSS_COMPILE=$(CROSS_COMPILE) -j8
	cp u-boot/ipl $(OUTPUTS)/gw302-ipl

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

buildroot-menuconfig-gw30x:
	$(MAKE) -C $(BUILDROOT_GW30X) buildroot-menuconfig

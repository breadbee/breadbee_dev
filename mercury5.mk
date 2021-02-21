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

rtk: uboot_m5
	cp u-boot/u-boot.bin $(OUTPUTS)/rtk

copy_rtk_m5_to_sd: rtk
	sudo mount /dev/sdc1 /mnt
	- sudo cp outputs/rtk /mnt/rtk
	sudo umount /mnt

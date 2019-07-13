.PHONY: linux upload

all: upload nor_ipl
linux:
	- rm linux/arch/arm/boot/zImage
	$(MAKE) -C linux ARCH=arm -j8 CROSS_COMPILE=arm-linux-gnueabihf- zImage dtbs
	cat linux/arch/arm/boot/zImage linux/arch/arm/boot/dts/msc313e-breadbee.dtb > linux/arch/arm/boot/zImage.msc313e
	cat linux/arch/arm/boot/zImage linux/arch/arm/boot/dts/msc313d-mc400l.dtb > linux/arch/arm/boot/zImage.msc313d

linux_config:
	$(MAKE) -C linux ARCH=arm -j8 CROSS_COMPILE=arm-linux-gnueabihf- menuconfig

linux_clean:
	$(MAKE) -C linux ARCH=arm -j8 CROSS_COMPILE=arm-linux-gnueabihf- clean

uboot:
	$(MAKE) -C u-boot msc313_breadbee_defconfig
	$(MAKE) -C u-boot CROSS_COMPILE=arm-linux-gnueabihf- -j12

upload: linux uboot kernel.fit
	scp linux/arch/arm/boot/zImage.msc313e tftp:/srv/tftp/zImage.msc313e
	scp linux/arch/arm/boot/dts/msc313e-breadbee.dtb tftp:/srv/tftp/msc313e-breadbee.dtb
	scp u-boot/spl/u-boot-spl.bin tftp:/srv/tftp/ubootspl.msc313e
	scp u-boot/u-boot.img tftp:/srv/tftp/uboot.msc313e
	scp kernel.fit tftp:/srv/tftp/kernel.fit.breadbee
#	scp linux/arch/arm/boot/zImage.msc313d tftp:/srv/tftp/zImage.msc313d
#	scp buildroot/output/images/rootfs.squashfs tftp:/srv/tftp/rootfs.msc313e

nor_ipl:	uboot kernel.fit
	rm -f nor_ipl
	dd if=/dev/zero ibs=1M count=16 | tr "\000" "\377" > nor_ipl
	dd conv=notrunc if=IPL.bin of=nor_ipl bs=1k seek=16
	dd conv=notrunc if=u-boot/spl/u-boot-spl.bin of=nor_ipl bs=1k seek=64
#	dd conv=notrunc if=/home/daniel/mstaruboot/u-boot.img of=nor_ipl bs=1k seek=128
	dd conv=notrunc if=u-boot/u-boot.img of=nor_ipl bs=1k seek=128
	dd conv=notrunc if=kernel.fit of=nor_ipl bs=1k seek=512
#	dd conv=notrunc if=iplspl of=nor bs=1k seek=64
#	dd conv=notrunc if=IPL_CUST.bin of=nor bs=1k seek=64
	#dd if=/dev/null of=largerfile.txt bs=1 count=0 seek=16777216

nor:	uboot kernel.fit
	rm -f nor
	dd if=/dev/zero ibs=1M count=16 | tr "\000" "\377" > nor
	dd conv=notrunc if=u-boot/spl/u-boot-spl.bin of=nor bs=1k seek=16
	dd conv=notrunc if=u-boot/u-boot.img of=nor bs=1k seek=128
#	dd conv=notrunc if=iplspl of=nor bs=1k seek=64
#	dd conv=notrunc if=IPL_CUST.bin of=nor bs=1k seek=64
	#dd if=/dev/null of=largerfile.txt bs=1 count=0 seek=16777216

kernel.fit: linux
	mkimage -f kernel.its kernel.fit

clean:
	rm -rf kernel.fit nor nor_ipl

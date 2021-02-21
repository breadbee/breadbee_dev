# Breadbee dev

This is a janky environment to manage building u-boot and kernel images so you can quickly
hack on u-boot or the kernel and test your work.

## Getting started

To get started you need to checkout this repo and then populate it with the u-boot, kernel
and buildroot sources by running the bootstrap target:

```
make bootstrap
```

Once this is complete any of the targets below should build. Note that the first build will
take a long time as the toolchain and rootfs build will be triggered. Subsequent builds will
reuse the toolchain and rootfs and will be much faster.

## Targets

### rtk

This is a special target that is not for the breadbee at all. Instead this is for development
using a mercury5 device. The m5 IPL looks for a file called ```rtk``` (real time kernel?) on 
the first FAT partition, loads it to DRAM and jumps into it. We can exploit this to load u-boot
into DRAM and start it.

This can be useful because the infinity3 (breadbee Soc) and mercury5 are very similar but the
mercury5 supports booting u-boot from SD card so it's a lot easier to work with than flashing
the SPI NOR each time.

```
make rtk
```

### spl

This builds the u-boot SPL, pads it and fixes up the image checksum so it can be loaded from
the IPL.

```
make spl
```

### kernel_m5.fit

This builds a kernel FIT image *without* the breadbee overlays but *with* the breadbee rescue initramfs.
This is mainly for testing on mercury5 where actually writing the rootfs to the SPI NOR would
destroy the existing firmware that is still useful for making sure the screen etc are still working.

```
make kernel_m5.fit
```

### kernel_breadbee.fit

This builds a kernel FIT image *with* the breadbee overlays and *without* any built in initramfs.
This is mainly for TFTP booting on a breadbee to test kernel changes with the rootfs already
being on SPI NOR.

```
make kernel_breadbee.fit
```

### kernel_ssd201htv2

This builds a kernel with an appended DTB for the ssd201htv2 with the vendor u-boot

```
mw 0x16002000 0x1e0; setenv serverip 192.168.3.235; setenv loadaddr 0x22000000; dhcp kernel_ssd201htv2; go ${loadaddr}
```

### kernel_gw302

This builds a kernel with an appended DTB for the gw302 with the vendor u-boot

```
mw 0x16002000 0x1e0; setenv serverip 192.168.3.235; setenv loadaddr 0x22000000; dhcp kernel_gw302; go ${loadaddr}
```

### kernel_ssd20x.fit

This builds a generic kernel for ssd20xd machines with an updated u-boot

```
setenv serverip 192.168.3.235; setenv loadaddr 0x22000000; dhcp dev_kernel_ssd20xd.fit; bootm ${loadaddr}
```


### kernel_mcf50

This builds a kernel with an appended DTB for the mcf50 with the vendor u-boot

```
mw 0x16002000 0x1e0; setenv serverip 192.168.3.235; setenv loadaddr 0x22000000; dhcp kernel_mcf50; go ${loadaddr}
```

## Booting up the outputs

#### Booting the dev kernel over TFTP

```
setenv serverip 192.168.3.235; setenv loadaddr 0x22000000; dhcp dev_kernel_breadbee.fit; bootm ${loadaddr}"#"${bb_boardtype}${bb_config}
```

###  Booting the vendor kernel over TFTP

```
setenv serverip 192.168.3.235; setenv loadaddr 0x22000000; dhcp dev_vendor.fit; bootm ${loadaddr}
```

###  Booting the dev kernel and override the configured overlays

```
setenv serverip 192.168.3.1; setenv loadaddr 0x22000000; dhcp kernel.fit.breadbee; bootm ${loadaddr}"#breadbee#sdio_sd"
```

# booting the kernel from sd card

## mercury5 midrive d06

```fatload mmc 0:1 $loadaddr kernel.fit; bootm $loadaddr#midrived06```

## mercury5 midrive d08

```fatload mmc 0:1 $loadaddr kernel.fit; bootm $loadaddr#midrive08```

## mercury5 mirror cam

```fatload mmc 0:1 $loadaddr kernel.fit; bootm $loadaddr#mirrorcam```

# Chain loading u-boot from another u-boot

```
setenv serverip 192.168.3.235; setenv loadaddr 0x22000000; dhcp generic-ipl;
cp.b $loadaddr 0xa0000000 0xbb80
go 0xa0000000
```


# Replacing u-boot on the breadbee

## Via ethernet

```
setenv serverip 192.168.3.235; if dhcp dev_u-boot_breadbee.img; then; sf probe; sf erase 0x20000 0x50000; sf write 0x22000000 0x20000 0x50000; fi
```

## Via uart

```
if loady ${loadaddr} 460800; then; sf probe; sf erase 0x20000 0x50000; sf write 0x22000000 0x20000 0x50000; fi
```

```
if loady ${loadaddr} 460800; then; sf probe; sf erase 0x10000 0x10000; sf write 0x22000000 0x10000 0x10000; fi
```


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
using a mercury5 device. This can be useful because the infinity3 (breadbee Soc) and mercury5
are very similar but the mercury5 supports booting u-boot from SD card so it's a lot easier to
work with than flashing the SPI NOR each time.

```
make rtk
```

### spl

This builds the u-boot SPL, pads it and fixes up the image checksum so it can be loaded from
the IPL.

```
make spl
```

## Booting up the outputs

### Booting the dev kernel over TFTP

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

# Booting the uboot + kernel fit RTK image

- copy the rtk file to your SD card
- wait until you get the uboot prompt
- type ```bootm 0x20048000#midrive08``` and hit enter


# Replacing u-boot

## Via ethernet

```
setenv serverip 192.168.3.235; if dhcp dev_u-boot.img; then; sf probe; sf erase 0x20000 0x50000; sf write 0x22000000 0x20000 0x50000; fi
```

## Via uart

```
if loady ${loadaddr} 460800; then; sf probe; sf erase 0x20000 0x50000; sf write 0x22000000 0x20000 0x50000; fi
```


## Testing DMA

```
cd /sys/module/dmatest/parameters/; \
echo dma0chan0 > channel; \
echo 1 > run; \
sleep 10; \
echo 0 > run
```

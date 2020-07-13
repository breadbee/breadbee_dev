# Breadbee dev

This is a janky environment to manage building u-boot and kernel images so you can quickly
hack on u-boot or the kernel and test your work.

## Targets

### breadbee

This is the target for the breadbee. It will generate all of the appropriate artifacts.

```
make breadbee
```
### m5

This is the target for the dash cam used for development, until the breadbee HW is available

```
make m5
```

### kernel_ssd201htv2

This builds a kernel with an appended DTB for the ssd201htv2 with the vendor u-boot

```
mw 0x16002000 0x1e0; setenv serverip 192.168.3.235; setenv loadaddr 0x22000000; dhcp kernel_ssd201htv2; go ${loadaddr}
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

# booting the kernel from sd card
```fatload mmc 0:1 $loadaddr kernel.fit; bootm $loadaddr#mirrorcam```

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


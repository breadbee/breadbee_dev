# Booting the dev kernel over TFTP

```
setenv serverip 192.168.3.235; setenv loadaddr 0x22000000; dhcp dev_kernel.fit; bootm ${loadaddr}"#"${bb_boardtype}${bb_config}
```

# Booting the vendor kernel over TFTP

```
setenv serverip 192.168.3.235; setenv loadaddr 0x22000000; dhcp dev_vendor.fit; bootm ${loadaddr}
```

# Booting the dev kernel and override the configured overlays

```
setenv serverip 192.168.3.1; setenv loadaddr 0x22000000; dhcp kernel.fit.breadbee; bootm ${loadaddr}"#breadbee#sdio_sd"
```


# Replacing u-boot

## Via ethernet

'''setenv serverip 192.168.3.235; if dhcp dev_u-boot.img; then; sf probe; sf erase 0x20000 0x50000; sf write 0x22000000 0x20000 0x50000; fi'''

## Via uart

'''if loady ${loadaddr} 460800; then; sf probe; sf erase 0x20000 0x50000; sf write 0x22000000 0x20000 0x50000; fi'''



## Testing DMA

```
cd /sys/module/dmatest/parameters/; \
echo dma0chan0 > channel; \
echo 1 > run; \
sleep 10; \
echo 0 > run
```

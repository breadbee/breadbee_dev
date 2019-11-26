setenv serverip 192.168.3.235; setenv loadaddr 0x22000000; dhcp dev_kernel.fit; bootm ${loadaddr}"#"${bb_boardtype}${bb_config}

setenv serverip 192.168.3.1; setenv loadaddr 0x22000000; dhcp kernel.fit.breadbee; bootm ${loadaddr}"#breadbee#sdio_sd"

setenv serverip 192.168.3.1; if dhcp dev_u-boot.img; then; sf probe; sf erase 0x20000 0x50000; sf write 0x22000000 0x20000 0x50000; fi

setenv serverip 192.168.3.235; dhcp dev_u-boot.img; sf probe; sf erase 0x20000 0x50000; sf write 0x22000000 0x20000 0x50000;


## Testing DMA

cd /sys/module/dmatest/parameters/; \
echo dma0chan0 > channel; \
echo 1 > run; \
sleep 10; \
echo 0 > run

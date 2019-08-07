setenv serverip 192.168.3.1; setenv loadaddr 0x22000000; dhcp kernel.fit.breadbee; bootm ${loadaddr}${bb_config}

setenv serverip 192.168.3.1; setenv loadaddr 0x22000000; dhcp kernel.fit.breadbee; bootm ${loadaddr}"#breadbee#sdio_sd"

setenv serverip 192.168.3.1; if dhcp dev_u-boot.img; then; sf probe; sf erase 0x20000 0x50000; sf write 0x22000000 0x20000 0x50000; fi

setenv serverip 192.168.3.235; dhcp dev_u-boot.img; sf probe; sf erase 0x20000 0x50000; sf write 0x22000000 0x20000 0x50000;

setenv serverip 192.168.3.1; setenv loadaddr 0x22000000; dhcp kernel.fit.breadbee; bootm ${loadaddr}${bb_config}

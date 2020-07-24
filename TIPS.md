dhcp rootfs.msc313e; sf probe; sf erase 0x400000 0xc00000; sf write ${loadaddr} 0x400000 0xc00000
sf probe; sf read ${loadaddr} 0x800000 0x800000; go ${loadaddr}


for gpio in `seq 486 493`; do echo $gpio > export; echo out > gpio$gpio/direction; done
while `true`; do for gpio in `seq 486 493`; do echo 1 > gpio$gpio/value; usleep 90000; echo 0 > gpio$gpio/value; usleep 90000; done; done


setenv serverip 192.168.3.1; dhcp zImage.msc313d; go 0x20006000

# Loading with ymodem

loady ${loadaddr} 460800

# booting with rtk

bootm ${loadaddr}#midrive08
bootm ${loadaddr}#midrive08_nrd
bootm ${loadaddr}#mirrorcam
bootm ${loadaddr}#mirrorcam_nrd

setenv bootargs "console=ttyS0,115200 rootwait root=/dev/mmcblk0p2 clk_ignore_unused earlyprintk=serial,ttyS0,115200"; bootm 0x20048000#mercury5_nrd

tftp -g -r rtk -l /tmp/rtk 192.168.3.235 && mount /dev/mmcblk0p1 /mnt/ && cp /tmp/rtk /mnt && umount /mnt

for B in `seq 0 63`; do BH=`echo obase=16\;ibase=10\;$B| bc;`; OFF=`echo obase=16\;ibase=16\;21000000+($BH*20000) | bc;`; echo md.b 0x$OFF 0x20000 > /dev/ttyUSB0; sleep 110; done


udhcpc && mount /dev/mmcblk0p1 /mnt && cd /mnt && tftp -g -r dev_kernel_m5.fit 192.168.3.235
fatload mmc 0:1 $loadaddr dev_kernel_m5.fit; bootm $loadaddr#midrive08

setenv bootargs "console=ttyS0,115200 root=/dev/mmcblk0p2 rootwait clk_ignore_unused earlyprintk=serial,ttyS0,115200"
fatload mmc 0:1 $loadaddr kernel.fit; bootm $loadaddr#midrive08

## Testing DMA

```
cd /sys/module/dmatest/parameters/; \
echo dma0chan0 > channel; \
echo 1 > run; \
sleep 10; \
echo 0 > run

## Updating m5 via usb ethernet

```
fatload mmc 0:1 $loadaddr dev_kernel_m5.fit; bootm $loadaddr#midrived06

udhcpc eth0; mkdir /boot; mount /dev/mmcblk0p1 /boot; cd /boot; tftp -r dev_kernel_m5.fit -g 192.168.3.235; cd /; umount /boot;
```

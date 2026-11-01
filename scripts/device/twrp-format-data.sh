#!/system/bin/sh
# Re-create /data and /cache the way the LineageOS build expects, from a TWRP shell.
# Run on the tablet, in TWRP:   adb shell < scripts/device/twrp-format-data.sh
#
# /data must leave the LAST 16 KB of the partition unused: Android keeps its encryption footer there
# (the fstab entry is `encryptable=footer`). A full-size filesystem makes the first boot fail.
# WARNING: wipes /data and /cache.
KB=$(awk '$4=="mmcblk0p8"{print $3}' /proc/partitions)
DATA_BLOCKS=$((KB / 4 - 4))                 # 4 KB blocks, minus 16 KB footer
KC=$(awk '$4=="mmcblk0p7"{print $3}' /proc/partitions)
CACHE_BLOCKS=$((KC / 4))

echo "userdata: ${KB} KB -> ${DATA_BLOCKS} blocks (16 KB footer reserved); cache: ${CACHE_BLOCKS} blocks"
umount /data 2>/dev/null
umount /cache 2>/dev/null
mke2fs -t ext4 -b 4096 -F -L userdata /dev/block/mmcblk0p8 $DATA_BLOCKS
mke2fs -t ext4 -b 4096 -F -L cache    /dev/block/mmcblk0p7 $CACHE_BLOCKS
mkdir -p /data /cache
mount -t ext4 /dev/block/mmcblk0p8 /data && mount -t ext4 /dev/block/mmcblk0p7 /cache
df -h /data /cache

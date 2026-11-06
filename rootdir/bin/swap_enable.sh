#!/system/bin/sh
#
# zram setup for CPH1909.
#
# MediaTek's stock /vendor/etc/init/hw/init.mt6765.rc defines
#
#     service swap_enable_init /system/bin/sh /system/etc/swap_enable.sh
#         user root
#         disabled
#         oneshot
#         seclabel u:r:rutilsdaemon:s0
#
# and starts it unconditionally from its `on fs` block, right after
# `mount_all /vendor/etc/fstab.mt6765`. The script lives on the system
# partition, so it is not part of the vendor blob extraction and has to be
# supplied by the device tree -- without it the service execs a missing script
# and the device boots with no swap at all.
#
# This is a rewrite rather than a copy of stock's script. Stock also writes
#     /proc/sys/vm/direct_swappiness
#     /sys/module/lowmemorykiller/parameters/almk_swap_ratio1
# neither of which exists here: the first is an OPPO vm patch absent from this
# kernel, and the second belonged to the in-kernel lowmemorykiller that Android
# 10 replaced with userspace lmkd. Every write below is guarded because a
# failed redirect in a oneshot service otherwise leaves zram unconfigured and
# swapon then fails silently.
#
# Sizes follow the stock table for this SoC family: <=2GB RAM -> 1.5GB zram,
# <=3GB -> 1.6GB, <=4GB -> 2GB, above that 1GB. CPH1909 ships in 2GB/3GB/4GB
# variants, so all three low branches are reachable on real hardware.
#
# The kernel has CONFIG_ZRAM=y and CONFIG_SWAP=y, and its comp_algorithm
# defaults to lz4; CONFIG_CRYPTO_ZSTD is not set, which is why the zstd write in
# init.mt6765.rc has no effect and lz4 is set explicitly here.

MemTotal=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
[ -z "$MemTotal" ] && exit 0

if [ "$MemTotal" -le 2097152 ]; then
    disksize=1610612736
    swappiness=180
elif [ "$MemTotal" -le 3145728 ]; then
    disksize=1717986918
    swappiness=160
elif [ "$MemTotal" -le 4194304 ]; then
    disksize=2147483648
    swappiness=160
else
    disksize=1073741824
    swappiness=160
fi

[ -w /sys/block/zram0/comp_algorithm ] && echo lz4 > /sys/block/zram0/comp_algorithm
[ -w /sys/block/zram0/disksize ] || exit 0
echo "$disksize" > /sys/block/zram0/disksize || exit 0
[ -w /proc/sys/vm/swappiness ] && echo "$swappiness" > /proc/sys/vm/swappiness

mkswap /dev/block/zram0 || exit 0
swapon /dev/block/zram0

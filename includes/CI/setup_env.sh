sudo pkg install -y py37-iocage
truncate -s 20g tmpdisk.img
sudo f. -h
sudo mdconfig -a -t vnode -f tmpdisk.img -u 0
sudo zpool create -f -o ashift=12 testpool /dev/md0
sudo zfs get mountpoint testpool
echo "this is env setup"
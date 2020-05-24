sudo pkg install -y py37-iocage
echo "starting truncate"
truncate -s 50g tmpdisk.img
echo "starting mdconfig"
sudo mdconfig -a -t vnode -f tmpdisk.img -u 0
echo "starting zpool"
sudo zpool create -f testpool /dev/md0
echo "starting zfs"
sudo zfs get mountpoint testpool
echo "this is env setup"
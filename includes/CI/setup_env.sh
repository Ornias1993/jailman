sudo pkg install -y py37-iocage
sudo mkdir /data
echo "starting truncate"
truncate -s 50g /data/tmpdisk.img
echo "starting zpool"
sudo zpool create testpool /data/tmpdisk.img
echo "starting zfs"
sudo zfs get mountpoint testpool
echo "this is env setup"
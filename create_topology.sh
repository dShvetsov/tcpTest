#!/usr/bin/env bash

# create ovs
br1=br1
br2=br2
br3=br3

if [ $UID -ne 0 ] ; then
    echo "Permission denied"
    exit 1
fi

echo "setup ovs-bridge"

clean_file="cleanup.sh"
echo "#!/usr/bin/env bash" > $clean_file
chmod +x $clean_file

for i in 1 2 3
do
    ovs-vsctl add-br br$i
    echo "ovs-vsctl del-br br$i" >> $clean_file
    ovs-vsctl del-controller br$i
    ovs-ofctl add-flow br$i actions=normal
done

echo "Setup virtual pair"
f1t2=br1-veth0
f2t1=br2-veth0
ip link add $f1t2 type veth peer name $f2t1
echo "ip link del $f1t2" >> $clean_file

f2t3=br2-veth1
f3t2=br3-veth0
ip link add $f2t3 type veth peer name $f3t2
echo "ip link del $f2t3" >> $clean_file

for i in $f1t2 $f2t1 $f2t3 $f3t2
do
    ip link set $i up
done

ip link list

echo "Setup ovs ports"

ovs-vsctl add-port br1 $f1t2
ovs-vsctl add-port br2 $f2t1
ovs-vsctl add-port br2 $f2t3
ovs-vsctl add-port br3 $f3t2

ovs-vsctl show

RATE=25mbit
QUEUE=80
DELAY="1.0ms"
LOSS="2.0%"

for DEVICE in $f1t2 $f2t1 $f2t3 $f3t2
do
    tc qdisc add dev "$DEVICE" root handle 1: tbf rate "${RATE}" burst 1536b limit "$(($QUEUE*1536))"
    tc qdisc add dev "$DEVICE" parent 1:1 handle 10: netem delay "${DELAY}" loss random "${LOSS}"
done


echo "Create virtual pair from host to switch"
echo "Configure netns"

for i in 1 2 3
do
    br=br$i
    ip netns add ns$i
    echo "ip netns del ns$i" >> $clean_file
    ibr=${br}-veth10
    ihost=h${i}-veth0
    ip link add $ibr type veth peer name $ihost
    echo "ip link del $ibr" >> $clean_file

    ip link set $ibr up

    ip link set $ihost netns ns$i
    echo "In netns ns$i"
    ip netns exec ns$i ifconfig $ihost 10.255.255.${i}/24
    ip netns exec ns$i ip link $ihost up
    ip netns exec ns$i ifconfig
    ovs-vsctl add-port $br $ibr
done

ovs-vsctl show

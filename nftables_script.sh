#!/bin/bash
echo "
This utility is designed for basic configuration of a firewall based on nftables rules.
To set up a firewall, please answer the questions step by step.
If you want to apply the rule, press the Y button. 
If you want to use the opposite policy, press the N button. 
To skip the rule, use any key. 
To get started, please enter a few variables:"

echo -n "Local int. name - "
read localint
LOCAL_INT=$localint

echo -n "External int. name - "
read extint
EXT_INT=$extint

echo -n "Local net - "
read localnet
LOCAL_NET=$localnet

echo -n "Server ip  - "
read webip
WEBSRV_IP=$webip

#echo -n "Ext. ip  - "
#read extip
#EXT_IP=$extip

#echo -n "local. ip  - "
#read localip
#LOCAL_IP=$localip
#Функция для создания базовой таблицы и цепочек
filt(){
nft add table inet filter
nft add chain inet filter input {type filter hook input priority 0 \; policy $1\;}
nft add chain inet filter forward {type filter hook forward priority 0 \; policy $2\;}
nft add chain inet filter output {type filter hook output priority 0 \; policy $3\;}
}
#Трафик на localhost
loc(){
nft add rule inet filter input iif lo $1
nft add rule inet filter output iif lo $1
}
#invalid трафик 
inv() {
nft add rule inet filter input ct state invalid drop
nft add rule inet filter output ct state invalid drop
nft add rule inet filter forward ct state invalid drop
}
#icmp
icmp() {
nft add rule inet filter input ip protocol icmp \
icmp type echo-request counter $1
nft add rule inet filter input icmp type time-exceeded $1
}
#DNS
dnss(){
nft add rule inet filter input udp sport 53 $1
nft add rule inet filter output udp dport 53 $1
nft add rule inet filter forward udp dport 53 $1
nft add rule inet filter input tcp sport 53 $1
nft add rule inet filter output tcp dport 53 $1
nft add rule inet filter forward tcp dport 53 $1
}
#Открытие закрытие портов
portt(){
    echo " -Which ports do you wants to $1. -
You can use a single one like 80, yo can use ',' like 80,443, and sets like 8000-8080 "
echo "------------------"
echo -n "Choose a chain - "
read chain 
   
echo -n "Enter ports number - "
read ports 

while true
do
    for str in $ports
    do
    nft add rule inet filter $chain tcp dport {$str} $1
    echo -n "Choose a chain - "
    read chain 
  
    done
       if [[ $chain = "next" ]]; then
       echo "All ports is accepted"
    break
  fi
    echo -n "Enter ports number - "
    read ports 
done
}
# блокировка пакетов с адресов/сетей
dropp(){
echo "8.Which adresses do you wants to $1."
read adr
for str in $adr
do
nft add rule inet filter input ip saddr {$str} $1
done
}
#nat
nat() {
nft add table ip nat
nft add chain ip nat prerouting {type nat hook prerouting priority 0 \; policy accept\;} 
nft add chain ip nat postrouting {type nat hook postrouting priority 100 \; policy accept\;}
nft add rule nat prerouting iifname $EXT_INT tcp dport {80, 443} dnat $WEBSRV_IP
nft add rule nat postrouting oifname $EXT_INT ip saddr $LOCAL_NET snat $WEBSRV_IP
}

systemctl disable --now firewalld
systemctl mask firewalld
echo "Please choose a policy for chains"
echo -n "INPUT - "
read inp
echo -n "FORWARD - "
read forw
echo -n "OUTPUT - "
read out




echo "1. Would you like to flush existing rules? y/n"
read doing
case $doing in
y)
echo "flushe rules..."
nft flush ruleset
filt $inp $forw $out
echo "rules is flushed"
;;
n)
filt $inp $forw $out
echo "next"
;;
*)
echo "Rules is not flashed"
;;
esac

echo "2.Do you want to accept you local traffic?"
read doing
case $doing in
y)
loc accept
echo "local traffic is accept"
;;
n)
loc drop
;;
*)
echo "next"
;;
esac

echo "3.Do you want to save established and related connections?"
read doing
case $doing in
y)
nft add rule inet filter input ct state established,related accept
echo "All established connection accept!"
;;
n)
nft add rule inet filter input ct state established,related drop
;;
*)
echo "next"
;;
esac

inv

echo "4.Do you want an ssh acces?"
read doing
case $doing in
y)
nft add rule inet filter input tcp dport 22 accept
echo "connection accept!"
;;
n)
nft add rule inet filter input tcp dport 22 drop
;;
*)
echo "next"
;;
esac

echo "5.Do you want to allow echo request messages?"
read doing
case $doing in
y)
icmp accept
echo "connection accept!"
;;
n)
icmp drop
;;
*)
echo "next"
;;
esac

echo "6.Do you want to open DNS ports?"
read doing
case $doing in
y)
dnss accept
echo "connection accept!"
;;
n)
dnss drop
;;
*)
echo "next"
;;
esac

echo "7.Do you want to configure ports?"
read doing
case $doing in
y)
portt accept
portt drop
echo "Ports is congigure;"
;;
*)
echo "next"
;;
esac

echo "8.Do you want to accept/block traffic from ip/net?"
read doing
case $doing in
y)
dropp accept
dropp drop
;;
*)
echo "next"
;;
esac

echo "9.Do you want to configure nat?"
read doing
case $doing in
y)
nat
echo "nat is congigure;"
echo "End!!"
;;
*)
echo "End!!"
;;
esac
echo "do you want to save rules?"
read answ
case $answ in 
y)
echo "Saving active rules to startup - /etc/nftables.conf"
        echo '#!/usr/sbin/nft -f' > /etc/nftables.conf
        echo 'flush ruleset' >> /etc/nftables.conf
       nft -s list ruleset >> /etc/nftables.conf
        echo "Don't forget to execute 'systemctl enable nftables'"
        ;;
*)
echo "END!!!"
;;
esac

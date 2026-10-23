#!/bin/sh
# Usage: firewall.sh open | apply | status
WEB=10.10.1.20
DB=10.10.3.30
ENG=10.10.1.0/24
FIN=10.10.2.0/24
DBN=10.10.3.0/24

reset() { iptables -F FORWARD; iptables -Z FORWARD; }

case "$1" in
  open)
    reset
    iptables -P FORWARD ACCEPT
    echo "[router] OPEN mode: everything is routed, no policy."
    ;;
  apply)
    reset
    iptables -P FORWARD DROP
    # 1. Allow replies to approved connections
    iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    # 2. Engineering -> Web on TCP/80
    iptables -A FORWARD -s $ENG -d $WEB -p tcp --dport 80 -m conntrack --ctstate NEW -j ACCEPT
    # 3. Web -> Database on TCP/5432
    iptables -A FORWARD -s $WEB -d $DB -p tcp --dport 5432 -m conntrack --ctstate NEW -j ACCEPT
    # 4. Explicit denies (each gets its own packet counter)
    iptables -A FORWARD -s $FIN -d $ENG -j DROP
    iptables -A FORWARD -s $FIN -d $DBN -j DROP
    iptables -A FORWARD -s $ENG -d $DBN -j DROP
    echo "[router] POLICY applied: default DROP."
    ;;
  status)
    iptables -L FORWARD -v -n --line-numbers
    ;;
  *)
    echo "usage: $0 open|apply|status"; exit 1;;
esac

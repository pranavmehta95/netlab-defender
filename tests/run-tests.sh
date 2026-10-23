#!/usr/bin/env bash
cd "$(dirname "$0")/.."
pass=0; fail=0

t() {  # usage: t "name" EXPECTED service command...
  local name=$1 expect=$2 svc=$3; shift 3
  if docker compose exec -T "$svc" "$@" >/dev/null 2>&1; then got=ALLOW; else got=DENY; fi
  if [ "$got" = "$expect" ]; then r=PASS; pass=$((pass+1)); else r=FAIL; fail=$((fail+1)); fi
  printf "%-4s | %-32s | expected %-5s | got %-5s\n" "$r" "$name" "$expect" "$got"
}

echo "RESULT | TEST                             | EXPECTED       | GOT"
t "Eng client -> Web   TCP/80"     ALLOW eng-client curl -s -m 3 http://10.10.1.20
t "Web -> DB           TCP/5432"   ALLOW web        nc -z -w 3 10.10.3.30 5432
t "Fin client -> Web   TCP/80"     DENY  fin-client nc -z -w 3 10.10.1.20 80
t "Eng client -> DB    TCP/5432"   DENY  eng-client nc -z -w 3 10.10.3.30 5432
t "Fin client -> DB    TCP/5432"   DENY  fin-client nc -z -w 3 10.10.3.30 5432
t "Fin client -> Eng   ICMP"       DENY  fin-client ping -c 1 -W 2 10.10.1.10

echo
echo "Passed: $pass   Failed: $fail"
echo
docker compose exec -T router sh /scripts/firewall.sh status

# NetLab Defender

A segmented virtual enterprise network built with Docker Compose. A Linux router
connects Engineering, Finance and Database subnets and enforces a default-deny
iptables policy based on least privilege. Lab use only.

## Topology

                    Engineering  10.10.1.0/24
                 eng-client .10       web .20
                            \         /
                             \       /
    Finance 10.10.2.0/24 --- [ ROUTER / FIREWALL ] --- Database 10.10.3.0/24
      fin-client .10        .1 on every subnet          db-server .30

| Host | IP | Default gateway |
|---|---|---|
| router | 10.10.1.1 / 10.10.2.1 / 10.10.3.1 | n/a |
| eng-client | 10.10.1.10 | 10.10.1.1 |
| web | 10.10.1.20 | 10.10.1.1 |
| fin-client | 10.10.2.10 | 10.10.2.1 |
| db-server | 10.10.3.30 | 10.10.3.1 |

## Run it

    docker compose up -d --build
    bash tests/run-tests.sh

The router applies the firewall policy automatically at startup (fail closed).
Use `docker compose exec router sh /scripts/firewall.sh open` to disable the
policy and `... apply` to restore it.

## Firewall policy

| Source | Destination | Service | Action | Why |
|---|---|---|---|---|
| Engineering | Web | TCP/80 | ALLOW | Staff use the internal app |
| Web | Database | TCP/5432 | ALLOW | Only the app tier needs the DB |
| Finance | Web / Engineering | any | DENY | Blocks lateral movement |
| Finance | Database | any | DENY | DB is never exposed to users |
| Engineering | Database | any | DENY | Users go through the app, not the DB |
| Reply traffic | n/a | ESTABLISHED,RELATED | ALLOW | Stateful: replies need no extra rules |

Everything not listed is dropped (FORWARD policy DROP).

## Tests

`tests/run-tests.sh` runs 6 checks (2 allowed, 4 denied) and prints the iptables
counters. Saved output is in `evidence/`. With the policy switched to open mode,
the 4 denied tests fail, which shows the tests detect a broken firewall.

## Design notes

- The web server is single-homed on the Engineering subnet. If it also sat on the
  database subnet, Web to DB traffic would be switched directly and would never
  reach the router, so the rule could not be enforced or tested.
- The Engineering to Web rule shows 0 packets because both hosts share a subnet,
  so their traffic never crosses the router. Finance to Web, which is routed, is
  what the firewall blocks.
- Denied traffic is DROPped (timeout) rather than REJECTed, revealing less.

## Limitations

Lab only, static rules, no production hardening, IPv4 only.

## Future work

Central logging, VLANs, IDS alerts, a DNS service, CI-run tests.

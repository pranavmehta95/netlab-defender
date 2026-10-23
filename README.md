# NetLab Defender 🔒

> A segmented virtual enterprise network built with Docker Compose. A Linux router
> connects Engineering, Finance and Database subnets and enforces a default-deny
> iptables policy based on least privilege. Lab use only.

## 📑 Table of Contents

- [Topology](#topology)
- [Quick Start](#quick-start)
- [Firewall Policy](#firewall-policy)
- [Tests](#tests)
- [Design Notes](#design-notes)
- [Limitations](#limitations)
- [Future Work](#future-work)
- [Demo Walkthrough](#demo-walkthrough)

## 🌐 Topology

```
                    Engineering  10.10.1.0/24
                 eng-client .10       web .20
                            \         /
                             \       /
    Finance 10.10.2.0/24 --- [ ROUTER / FIREWALL ] --- Database 10.10.3.0/24
      fin-client .10        .1 on every subnet          db-server .30
```

| Host | IP | Default gateway |
|---|---|---|
| 🖥️ router | 10.10.1.1 / 10.10.2.1 / 10.10.3.1 | n/a |
| 💻 eng-client | 10.10.1.10 | 10.10.1.1 |
| 🌐 web | 10.10.1.20 | 10.10.1.1 |
| 💼 fin-client | 10.10.2.10 | 10.10.2.1 |
| 🗄️ db-server | 10.10.3.30 | 10.10.3.1 |

## 🚀 Quick Start

```bash
docker compose up -d --build
bash tests/run-tests.sh
```

The router applies the firewall policy automatically at startup (fail closed).

### Firewall Control

```bash
# Disable the policy
docker compose exec router sh /scripts/firewall.sh open

# Restore the policy
docker compose exec router sh /scripts/firewall.sh apply

# Check current status
docker compose exec router sh /scripts/firewall.sh status
```

## 🛡️ Firewall Policy

| Source | Destination | Service | Action | Why |
|---|---|---|---|---|
| Engineering | Web | TCP/80 | ✅ ALLOW | Staff use the internal app |
| Web | Database | TCP/5432 | ✅ ALLOW | Only the app tier needs the DB |
| Finance | Web / Engineering | any | 🚫 DENY | Blocks lateral movement |
| Finance | Database | any | 🚫 DENY | DB is never exposed to users |
| Engineering | Database | any | 🚫 DENY | Users go through the app, not the DB |
| Reply traffic | n/a | ESTABLISHED,RELATED | ✅ ALLOW | Stateful: replies need no extra rules |

> Everything not listed is dropped (FORWARD policy DROP).

## 🧪 Tests

`tests/run-tests.sh` runs 6 checks (2 allowed, 4 denied) and prints the iptables
counters. Saved output is in `evidence/`.

### Test Behavior

- ✅ **2 allowed tests** - Should pass when firewall is active
- 🚫 **4 denied tests** - Should fail when firewall is active (pass when open)

With the policy switched to open mode, the 4 denied tests fail, which shows the tests detect a broken firewall.

## 📝 Design Notes

- The web server is single-homed on the Engineering subnet. If it also sat on the
  database subnet, Web to DB traffic would be switched directly and would never
  reach the router, so the rule could not be enforced or tested.
- The Engineering to Web rule shows 0 packets because both hosts share a subnet,
  so their traffic never crosses the router. Finance to Web, which is routed, is
  what the firewall blocks.
- Denied traffic is DROPped (timeout) rather than REJECTed, revealing less.

## ⚠️ Limitations

- Lab only
- Static rules
- No production hardening
- IPv4 only

## 🔮 Future Work

- Central logging
- VLANs
- IDS alerts
- DNS service
- CI-run tests

## 🎬 Demo Walkthrough

> Total time: about 3 minutes. Run these from the project root.

<details>
<summary>📦 Setup</summary>

```bash
export DOCKER_CLI_HINTS=false
docker compose down && docker compose up -d
docker compose exec router sh /scripts/firewall.sh apply
```

Wait about 10 seconds for PostgreSQL to start. The `apply` step resets the
iptables counters so the final table shows only the demo traffic.

</details>

<details>
<summary>1️⃣ Show the topology</summary>

```bash
docker compose ps
docker compose exec router ip -br addr | grep eth
```

**Expected:** five running containers, and the router has one interface in each
subnet (10.10.1.1, 10.10.2.1, 10.10.3.1). Interface names (eth0, eth1, eth2)
can change between runs, so match them by IP address.

</details>

<details>
<summary>2️⃣ Allowed: Engineering reaches the web server</summary>

```bash
docker compose exec eng-client curl -s -m 3 http://10.10.1.20 | head -3
```

**Expected:** the start of the nginx welcome page.

</details>

<details>
<summary>3️⃣ Denied: users cannot reach the database or each other</summary>

```bash
docker compose exec eng-client nc -zv -w 2 10.10.3.30 5432
docker compose exec fin-client nc -zv -w 2 10.10.1.20 80
```

**Expected:** both time out. Denied packets are dropped silently by the router.

</details>

<details>
<summary>4️⃣ Allowed: only the web server reaches the database</summary>

```bash
docker compose exec web nc -zv -w 2 10.10.3.30 5432
```

**Expected:** `succeeded!`

</details>

<details>
<summary>5️⃣ Prove it with the firewall counters</summary>

```bash
docker compose exec router sh /scripts/firewall.sh status
```

**Expected:** packets on the Web to DB accept rule and on the drop rules for the
denied flows. The Engineering to Web counter stays at 0 because both hosts share
a subnet, so that traffic never crosses the router.

</details>

<details>
<summary>6️⃣ Prove it with a packet capture (optional)</summary>

In one terminal:

```bash
docker compose exec router tcpdump -ni any "tcp port 5432"
```

In a second terminal, run the allowed and denied database tests from steps 3
and 4. Allowed traffic shows an In and an Out line plus the full TCP handshake.
Denied traffic shows only repeated SYN packets coming In, with no Out and no
reply, because the router discarded them.

</details>

<details>
<summary>7️⃣ Prove the tests detect a broken firewall (optional)</summary>

```bash
docker compose exec router sh /scripts/firewall.sh open
bash tests/run-tests.sh
docker compose exec router sh /scripts/firewall.sh apply
```

**Expected:** with the policy off, the 4 denied tests fail. Run `apply` afterwards
to restore the policy.

</details>

---

### 🤖 Automated Version

```bash
bash tests/run-tests.sh
```

Runs all 6 checks and prints PASS or FAIL for each, then the counters.

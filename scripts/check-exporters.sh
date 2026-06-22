#!/usr/bin/env bash
#
# check-exporters.sh — Vérifie que les exporters alimentent les dashboards Tier 1 (projet CIA).
#
# Trois niveaux :
#   [PROM] la métrique existe côté Prometheus (ce que lit le dashboard)
#   [LOKI] le label existe côté Loki (ce que lit les panneaux logs)
#   [HTTP] l'endpoint /metrics de l'exporter répond (debug bas niveau)
#
# Usage :
#   ./check-exporters.sh
#   PROM_URL=http://10.20.0.10:9090 LOKI_URL=http://10.20.0.10:3100 ./check-exporters.sh
#
# Surcharge possible via variables d'environnement (voir section CONFIG).

set -uo pipefail

# ----------------------------- CONFIG ---------------------------------------
PROM_URL="${PROM_URL:-http://localhost:9090}"
LOKI_URL="${LOKI_URL:-http://localhost:3100}"

# Endpoints exporters (pour les checks [HTTP] optionnels). Adapte les hôtes.
NODE_EXPORTER="${NODE_EXPORTER:-http://localhost:9100/metrics}"
PVE_EXPORTER="${PVE_EXPORTER:-http://localhost:9221}"
PVE_TARGET="${PVE_TARGET:-}"                 # ex: 10.10.0.10 (hôte Proxmox à interroger)
OPENVPN_EXPORTER="${OPENVPN_EXPORTER:-http://localhost:9176/metrics}"
BLACKBOX_EXPORTER="${BLACKBOX_EXPORTER:-http://localhost:9115}"
REMOTE_GW="${REMOTE_GW:-}"                   # ex: 10.20.0.1 (passerelle LAN du site distant)
PFSENSE_TELEGRAF="${PFSENSE_TELEGRAF:-http://localhost:9273/metrics}"
# ----------------------------------------------------------------------------

G="\033[0;32m"; R="\033[0;31m"; Y="\033[0;33m"; B="\033[0;34m"; N="\033[0m"
PASS=0; FAIL=0; WARN=0

hdr()  { printf "\n${B}== %s ==${N}\n" "$1"; }
ok()   { printf "  ${G}[OK]${N}   %s\n" "$1"; PASS=$((PASS+1)); }
ko()   { printf "  ${R}[FAIL]${N} %s\n" "$1"; FAIL=$((FAIL+1)); }
warn() { printf "  ${Y}[WARN]${N} %s\n" "$1"; WARN=$((WARN+1)); }

# La métrique existe dans Prometheus (résultat non vide) ?
prom_has() { # $1=promql  $2=libellé
  local r; r=$(curl -fs --max-time 5 --data-urlencode "query=$1" "$PROM_URL/api/v1/query" 2>/dev/null)
  if [[ -z "$r" ]]; then ko "$2 — Prometheus injoignable ($PROM_URL)"; return; fi
  if echo "$r" | grep -q '"result":\[\]'; then ko "$2 — métrique absente ($1)"
  elif echo "$r" | grep -q '"status":"success"'; then ok "$2"
  else warn "$2 — réponse inattendue"; fi
}

# Un label Loki contient une valeur attendue ?
loki_has_value() { # $1=label  $2=valeur  $3=libellé
  local r; r=$(curl -fs --max-time 5 "$LOKI_URL/loki/api/v1/label/$1/values" 2>/dev/null)
  if [[ -z "$r" ]]; then ko "$3 — Loki injoignable ($LOKI_URL)"; return; fi
  if echo "$r" | grep -q "\"$2\""; then ok "$3"
  else ko "$3 — label '$1' sans valeur '$2'"; fi
}

# Endpoint exporter répond et expose la métrique ?
http_has() { # $1=url  $2=motif  $3=libellé
  local r; r=$(curl -fs --max-time 5 "$1" 2>/dev/null)
  if [[ -z "$r" ]]; then warn "$3 — endpoint muet ($1)"
  elif echo "$r" | grep -q "$2"; then ok "$3"
  else warn "$3 — '$2' absent de $1"; fi
}

# ============================ BACKENDS =======================================
hdr "Backends"
curl -fs --max-time 5 "$PROM_URL/-/ready" >/dev/null 2>&1 && ok "Prometheus ready ($PROM_URL)" || ko "Prometheus KO ($PROM_URL)"
curl -fs --max-time 5 "$LOKI_URL/ready"   >/dev/null 2>&1 && ok "Loki ready ($LOKI_URL)"       || ko "Loki KO ($LOKI_URL)"

hdr "Cibles Prometheus (santé globale)"
TGT=$(curl -fs --max-time 5 "$PROM_URL/api/v1/targets" 2>/dev/null)
if [[ -n "$TGT" ]]; then
  UP=$(echo "$TGT" | grep -o '"health":"up"' | wc -l)
  DOWN=$(echo "$TGT" | grep -o '"health":"down"' | wc -l)
  [[ "$DOWN" -eq 0 ]] && ok "$UP cible(s) up, 0 down" || warn "$UP up / $DOWN down — inspecter /targets"
else ko "Impossible de lire /api/v1/targets"; fi

# ====================== DASHBOARD 1 : VPN ====================================
hdr "Dashboard VPN Site-to-Site"
prom_has 'openvpn_up'                              "openvpn_up (état tunnel)"
prom_has 'openvpn_server_connected_clients'       "pairs connectés"
prom_has 'openvpn_status_update_time_seconds'     "fraîcheur du statut"
prom_has 'openvpn_server_client_received_bytes_total' "débit RX par pair"
prom_has 'probe_duration_seconds{job=~"blackbox.*"}'  "latence inter-site (blackbox)"
loki_has_value job openvpn                         "logs OpenVPN (job=openvpn)"

# ====================== DASHBOARD 2 : pfSense ================================
hdr "Dashboard Pare-feu pfSense"
prom_has 'net_bytes_recv'                          "débit interfaces (Telegraf net)"
prom_has 'cpu_usage_idle{cpu="cpu-total"}'         "CPU pfSense"
prom_has 'mem_used_percent'                        "mémoire pfSense"
loki_has_value job pfsense                         "logs pfSense (job=pfsense)"
loki_has_value action block                        "extraction promtail (action=block)"
loki_has_value src_ip ""                           "extraction promtail (src_ip)" 2>/dev/null || \
  { r=$(curl -fs --max-time 5 "$LOKI_URL/loki/api/v1/labels" 2>/dev/null); \
    echo "$r" | grep -q '"src_ip"' && ok "extraction promtail (src_ip)" || warn "label src_ip absent — pipeline promtail à compléter"; }

# ====================== DASHBOARD 3 : Bastion ===============================
hdr "Dashboard Bastion · Accès & Sécurité"
loki_has_value job bastion                         "logs bastion (job=bastion)"

# ====================== DASHBOARD 4 : Proxmox ===============================
hdr "Dashboard Infrastructure Proxmox"
prom_has 'pve_up'                                  "pve_up (noeuds/VMs)"
prom_has 'pve_cpu_usage_ratio'                     "CPU par noeud"
prom_has 'pve_memory_usage_bytes'                  "mémoire"
prom_has 'pve_guest_info'                          "inventaire VMs"
prom_has 'node_load1'                              "node_exporter (charge VMs)"

# ====================== DASHBOARD 5 : NetBox + PostgreSQL ===================
hdr "Dashboard NetBox & PostgreSQL"
prom_has 'probe_success{job="blackbox_http_netbox"}'   "NetBox dispo (blackbox http)"
prom_has 'pg_up'                                       "PostgreSQL up (postgres_exporter)"
prom_has 'pg_stat_database_numbackends'                "connexions PostgreSQL"
prom_has 'pg_database_size_bytes'                      "taille des bases"

# ====================== DASHBOARD 6 : Site web interne ======================
hdr "Dashboard Site web interne"
prom_has 'probe_success{job="blackbox_http_internal"}' "site interne (blackbox http)"
prom_has 'probe_http_status_code{job="blackbox_http_internal"}' "code HTTP"

# ====================== DASHBOARD 7 : DNS forwarding ========================
hdr "Dashboard DNS forwarding"
prom_has 'probe_success{job="blackbox_dns"}'           "résolution DNS (blackbox dns)"
prom_has 'probe_dns_lookup_time_seconds{job="blackbox_dns"}' "latence DNS"

# ====================== Checks bas niveau (optionnels) ======================
hdr "Endpoints exporters (debug bas niveau)"
http_has "$NODE_EXPORTER"     '^node_load1'        "node_exporter ($NODE_EXPORTER)"
http_has "$OPENVPN_EXPORTER"  '^openvpn_up'        "openvpn_exporter ($OPENVPN_EXPORTER)"
http_has "$PFSENSE_TELEGRAF"  'net_bytes_recv'     "telegraf pfSense ($PFSENSE_TELEGRAF)"
[[ -n "$PVE_TARGET" ]] && http_has "$PVE_EXPORTER/pve?target=$PVE_TARGET" 'pve_up' "pve-exporter (target=$PVE_TARGET)" \
  || warn "pve-exporter non testé — exporte PVE_TARGET=<hôte_proxmox>"
[[ -n "$REMOTE_GW" ]] && http_has "$BLACKBOX_EXPORTER/probe?target=$REMOTE_GW&module=icmp" 'probe_success 1' "blackbox ICMP vers $REMOTE_GW" \
  || warn "blackbox non testé — exporte REMOTE_GW=<gw_site_distant>"

# ============================ RÉSUMÉ ========================================
printf "\n${B}== Résumé ==${N}\n  ${G}%d OK${N}   ${R}%d FAIL${N}   ${Y}%d WARN${N}\n" "$PASS" "$FAIL" "$WARN"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
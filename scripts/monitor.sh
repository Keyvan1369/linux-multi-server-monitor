#!/usr/bin/env bash

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONF="$BASE_DIR/config/servers.conf"
COLLECTOR="$BASE_DIR/scripts/collect-metrics.sh"
REPORT_DIR="$BASE_DIR/reports"
CSV="$REPORT_DIR/report_$(date +%F).csv"

SSH_USER="vagrant"
CPU_WARN=80
RAM_WARN=80
DISK_WARN=85

mkdir -p "$REPORT_DIR"
[ -f "$CSV" ] || echo "timestamp,server,hostname,status,load,cpu,ram,disk,alert" > "$CSV"

TS=$(date '+%Y-%m-%d %H:%M:%S')
total=0; online=0; offline=0; alerts=0

echo "=========================================================="
echo "          LINUX MULTI-SERVER HEALTH MONITOR"
echo "          $TS"
echo "=========================================================="
printf "%-8s %-16s %-8s %-6s %-6s %-6s %s\n" SERVER HOSTNAME STATUS LOAD CPU RAM DISK
echo "----------------------------------------------------------"

while IFS=: read -r name target; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  total=$((total + 1))

  if [ "$target" = "local" ]; then
    out=$(bash "$COLLECTOR" 2>/dev/null)
  else
    out=$(ssh -o BatchMode=yes -o ConnectTimeout=3 \
              -o StrictHostKeyChecking=accept-new \
              "${SSH_USER}@${target}" 'bash -s' < "$COLLECTOR" 2>/dev/null)
  fi

  if [ -z "$out" ]; then
    offline=$((offline + 1))
    printf "%-8s %-16s %-8s %-6s %-6s %-6s %s\n" "$name" "-" "OFFLINE" "-" "-" "-" "-"
    echo "$TS,$name,-,OFFLINE,-,-,-,-,SERVER_DOWN" >> "$CSV"
    continue
  fi

  online=$((online + 1))
  IFS=, read -r host load cpu ram disk <<< "$out"

  alert=""
  [ "$cpu"  -ge "$CPU_WARN"  ] && alert+="HIGH_CPU "
  [ "$ram"  -ge "$RAM_WARN"  ] && alert+="HIGH_RAM "
  [ "$disk" -ge "$DISK_WARN" ] && alert+="HIGH_DISK "
  [ -n "$alert" ] && alerts=$((alerts + 1))

  printf "%-8s %-16s %-8s %-6s %-6s %-6s %s %s\n" \
    "$name" "$host" "ONLINE" "$load" "${cpu}%" "${ram}%" "${disk}%" "${alert:+⚠ $alert}"
  echo "$TS,$name,$host,ONLINE,$load,$cpu,$ram,$disk,${alert:-OK}" >> "$CSV"
done < "$CONF"

echo "----------------------------------------------------------"
echo "TOTAL: $total | ONLINE: $online | OFFLINE: $offline | ALERTS: $alerts"
echo "Report saved: $CSV"

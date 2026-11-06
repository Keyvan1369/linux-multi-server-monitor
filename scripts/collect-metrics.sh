#!/usr/bin/env bash
# Prints: hostname,load1,cpu%,ram%,disk%

host=$(hostname)
load=$(cut -d' ' -f1 /proc/loadavg)

read -r _ u1 n1 s1 i1 w1 q1 sq1 _ < /proc/stat
sleep 1
read -r _ u2 n2 s2 i2 w2 q2 sq2 _ < /proc/stat

idle1=$((i1 + w1)); idle2=$((i2 + w2))
tot1=$((u1 + n1 + s1 + i1 + w1 + q1 + sq1))
tot2=$((u2 + n2 + s2 + i2 + w2 + q2 + sq2))

dt=$((tot2 - tot1))
di=$((idle2 - idle1))
if [ "$dt" -gt 0 ]; then
  cpu=$(( 100 * (dt - di) / dt ))
else
  cpu=0
fi

ram=$(free | awk '/^Mem:/{printf "%d", ($2-$7)*100/$2}')
disk=$(df / | awk 'NR==2{gsub("%","",$5); print $5}')

echo "${host},${load},${cpu},${ram},${disk}"

cat /proc/loadavg | \
awk -v h="$(uname -n)" -v cpus="$(nproc)" '{ printf h ",%s,%s", cpus, $3 }' && free -m | \
awk 'NR==2{printf ",%s/%sMB,%.2f%%\n", $3, $2, $3/$2*100}'

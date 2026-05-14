#!/bin/bash

# ============================================
# Server Performance Analysis Script
# ============================================

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Header
echo "=========================================="
echo "     SERVER PERFORMANCE ANALYSIS"
echo "=========================================="
echo ""

# ============================================
# 1. OS VERSION
# ============================================
echo -e "${BLUE}[1] OS VERSION${NC}"
echo "------------------------------------------"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "OS: $NAME $VERSION"
else
    lsb_release -a 2>/dev/null || cat /etc/issue
fi
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo ""

# ============================================
# 2. UPTIME
# ============================================
echo -e "${BLUE}[2] SYSTEM UPTIME${NC}"
echo "------------------------------------------"
echo "Uptime: $(uptime -p | sed 's/up //')"
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo "Current Time: $(date)"
echo ""

# ============================================
# 3. LOGGED IN USERS
# ============================================
echo -e "${BLUE}[3] LOGGED IN USERS${NC}"
echo "------------------------------------------"
echo "Users currently logged in:"
who | awk '{print "  - " $1 " (from " $5 " since " $3 " " $4 ")"}'
echo "Total: $(who | wc -l) user(s)"
echo ""

# ============================================
# 4. FAILED LOGIN ATTEMPTS
# ============================================
echo -e "${BLUE}[4] FAILED LOGIN ATTEMPTS (last 24h)${NC}"
echo "------------------------------------------"
if [ -f /var/log/auth.log ]; then
    FAILED_COUNT=$(grep "Failed password" /var/log/auth.log 2>/dev/null | grep "$(date +%b %e)" | wc -l)
    echo "Failed attempts today: $FAILED_COUNT"
    echo ""
    echo "Last 5 failed attempts:"
    grep "Failed password" /var/log/auth.log 2>/dev/null | tail -5 | while read line; do
        echo "  - $(echo $line | awk '{print $1, $2, $3, $11, $13}')"
    done
elif [ -f /var/log/secure ]; then
    FAILED_COUNT=$(grep "Failed password" /var/log/secure 2>/dev/null | grep "$(date +%b %e)" | wc -l)
    echo "Failed attempts today: $FAILED_COUNT"
else
    echo "Auth log not found (run with sudo for better results)"
fi
echo ""

# ============================================
# 5. TOTAL CPU USAGE
# ============================================
echo -e "${BLUE}[5] CPU USAGE${NC}"
echo "------------------------------------------"
# Get CPU usage percentage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
if [ -z "$CPU_USAGE" ]; then
    CPU_USAGE=$(top -bn1 | grep "%Cpu" | awk '{print $2}')
fi
echo "Total CPU Usage: ${CPU_USAGE}%"

# CPU Info
echo "CPU Model: $(lscpu | grep "Model name" | cut -d':' -f2 | xargs)"
echo "CPU Cores: $(nproc)"
echo ""

# ============================================
# 6. TOTAL MEMORY USAGE
# ============================================
echo -e "${BLUE}[6] MEMORY USAGE${NC}"
echo "------------------------------------------"
# Get memory stats
MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
MEM_FREE=$(free -h | awk '/^Mem:/ {print $4}')
MEM_AVAIL=$(free -h | awk '/^Mem:/ {print $7}')
MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.1f", $3/$2 * 100}')

echo "Total Memory: $MEM_TOTAL"
echo "Used Memory: $MEM_USED ($MEM_PERCENT%)"
echo "Free Memory: $MEM_FREE"
echo "Available Memory: $MEM_AVAIL"

# Swap usage
SWAP_TOTAL=$(free -h | awk '/^Swap:/ {print $2}')
if [ "$SWAP_TOTAL" != "0B" ]; then
    SWAP_USED=$(free -h | awk '/^Swap:/ {print $3}')
    SWAP_PERCENT=$(free | awk '/^Swap:/ {if ($2>0) printf "%.1f", $3/$2 * 100; else print "0"}')
    echo "Swap Total: $SWAP_TOTAL"
    echo "Swap Used: $SWAP_USED ($SWAP_PERCENT%)"
fi
echo ""

# ============================================
# 7. TOTAL DISK USAGE
# ============================================
echo -e "${BLUE}[7] DISK USAGE${NC}"
echo "------------------------------------------"
# Main disk usage
df -h --total | grep -E "^/dev/|^total" | while read line; do
    if echo "$line" | grep -q "^total"; then
        echo -e "${YELLOW}$line${NC}"
    else
        echo "$line"
    fi
done
echo ""

# Top 5 largest directories in /home (if exists)
if [ -d /home ]; then
    echo "Top 5 largest directories in /home:"
    du -sh /home/* 2>/dev/null | sort -rh | head -5 | sed 's/^/  /'
    echo ""
fi

# ============================================
# 8. TOP 5 PROCESSES BY CPU
# ============================================
echo -e "${BLUE}[8] TOP 5 PROCESSES BY CPU USAGE${NC}"
echo "------------------------------------------"
ps aux --sort=-%cpu | head -6 | awk 'NR==1 {printf "%-10s %-10s %-8s %-s\n", "USER", "PID", "%CPU", "COMMAND"}
NR>1 {printf "%-10s %-10s %-8.1f %-s\n", $1, $2, $3, substr($0, index($0,$11))}'
echo ""

# ============================================
# 9. TOP 5 PROCESSES BY MEMORY
# ============================================
echo -e "${BLUE}[9] TOP 5 PROCESSES BY MEMORY USAGE${NC}"
echo "------------------------------------------"
ps aux --sort=-%mem | head -6 | awk 'NR==1 {printf "%-10s %-10s %-8s %-s\n", "USER", "PID", "%MEM", "COMMAND"}
NR>1 {printf "%-10s %-10s %-8.1f %-s\n", $1, $2, $4, substr($0, index($0,$11))}'
echo ""

# ============================================
# 10. NETWORK SUMMARY (Optional)
# ============================================
echo -e "${BLUE}[10] NETWORK SUMMARY${NC}"
echo "------------------------------------------"
# Get primary IP
IP_ADDR=$(ip route get 1 2>/dev/null | awk '{print $7; exit}')
if [ -n "$IP_ADDR" ]; then
    echo "Primary IP: $IP_ADDR"
fi

# Network connections
echo "Active network connections:"
ss -tunp 2>/dev/null | tail -5 | while read line; do
    echo "  $line"
done
echo ""

# ============================================
# FOOTER
# ============================================
echo "=========================================="
echo "     ANALYSIS COMPLETE"
echo "=========================================="

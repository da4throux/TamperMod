#!/usr/bin/env bash
# scripts/bridge_dwarf.sh
# Bridges MOD Dwarf (192.168.51.1:80) to Crostini Linux container IP (100.115.92.201:80)
# This allows the ChromeOS Android subsystem (ARC / Hatch) to connect to MOD Dwarf via USB.

set -e

CROSTINI_IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
DWARF_IP="192.168.51.1"

echo "=================================================="
echo "TamperMod - ChromeOS Android / MOD Dwarf Bridge"
echo "=================================================="
echo "Crostini IP: ${CROSTINI_IP}"
echo "MOD Dwarf IP: ${DWARF_IP}"
echo ""

if ! ping -c 1 -W 1 "${DWARF_IP}" > /dev/null 2>&1; then
    echo "⚠️ WARNING: Cannot ping MOD Dwarf at ${DWARF_IP}."
    echo "Please make sure your MOD Dwarf is plugged in via USB."
fi

# Check if socat is installed
if ! command -v socat > /dev/null 2>&1; then
    echo "Installing socat..."
    sudo apt-get update && sudo apt-get install -y socat
fi

# Check if bridge is already running
if pgrep -f "socat TCP-LISTEN:80" > /dev/null 2>&1; then
    echo "✅ Bridge is already running on port 80."
else
    echo "Starting bridge on ${CROSTINI_IP}:80 -> ${DWARF_IP}:80..."
    sudo nohup socat TCP-LISTEN:80,fork,reuseaddr TCP:${DWARF_IP}:80 > /dev/null 2>&1 &
    sleep 1
    if pgrep -f "socat TCP-LISTEN:80" > /dev/null 2>&1; then
        echo "✅ Bridge successfully started!"
    else
        echo "❌ Failed to start bridge."
        exit 1
    fi
fi

echo ""
echo "📱 In TamperMod running on Chromebook (Hatch / ARC):"
echo "   Enter IP: ${CROSTINI_IP}"
echo "   Tap: CONNECT"
echo "=================================================="

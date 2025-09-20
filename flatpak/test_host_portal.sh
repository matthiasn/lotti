#!/bin/bash

echo "=== Host System Portal Check ==="
echo ""

# Check if portal packages are installed
echo "1. Checking installed portal packages:"
dpkg -l | grep -E "xdg-desktop-portal|portal" | grep -v "^rc" || echo "   No portal packages found"
echo ""

# Check if portal service is running
echo "2. Checking portal service status:"
systemctl --user status xdg-desktop-portal.service --no-pager 2>&1 | head -20
echo ""

# Check portal backend
echo "3. Checking portal backend service:"
systemctl --user status xdg-desktop-portal-gtk.service --no-pager 2>&1 | head -10 || \
systemctl --user status xdg-desktop-portal-kde.service --no-pager 2>&1 | head -10 || \
echo "   No backend service running"
echo ""

# Check portal configuration
echo "4. Portal configuration files:"
ls -la /usr/share/xdg-desktop-portal/portals/ 2>/dev/null || echo "   Portal configs not found"
echo ""

# Check D-Bus activation files
echo "5. D-Bus service files:"
ls -la /usr/share/dbus-1/services/ | grep portal || echo "   No portal D-Bus services found"
echo ""

# Try to manually start portal if not running
echo "6. Attempting to start portal service:"
systemctl --user start xdg-desktop-portal.service 2>&1
systemctl --user start xdg-desktop-portal-gtk.service 2>&1 || \
systemctl --user start xdg-desktop-portal-kde.service 2>&1 || true
echo "   Portal services started/restarted"
echo ""

# Test portal directly
echo "7. Testing Screenshot portal on host:"
gdbus call --session \
    --dest org.freedesktop.portal.Desktop \
    --object-path /org/freedesktop/portal/desktop \
    --method org.freedesktop.portal.Screenshot.Screenshot \
    "" "{}" 2>&1 | head -10
echo ""

echo "=== End of host check ==="
#!/usr/bin/env bash
# Waybar custom module: libvirt VM status (default: rocky-maya)
# Outputs JSON: {text, tooltip, class}. Prints nothing if the VM isn't
# defined on this machine, which hides the module.
VM="${1:-rocky-maya}"
# Nerd Font monitor icon (U+F0379) as a JSON \u escape, like dropbox-status.sh.
ICON='󰍹'

state=$(virsh -c qemu:///system domstate "$VM" 2>/dev/null) || exit 0

case "$state" in
    running)
        mem=$(virsh -c qemu:///system dominfo "$VM" | awk '/^Used memory/ {printf "%.0fG", $3/1048576}')
        cpus=$(virsh -c qemu:///system dominfo "$VM" | awk '/^CPU\(s\)/ {print $2}')
        printf '{"text":"%s  Maya VM","tooltip":"%s running\\n%s vCPU  •  %s RAM\\nLeft-click: open console  •  Right-click: virt-manager","class":"running"}\n' "$ICON" "$VM" "$cpus" "$mem"
        ;;
    paused)
        printf '{"text":"%s  Maya VM paused","tooltip":"%s paused\\nLeft-click: open console  •  Right-click: virt-manager","class":"paused"}\n' "$ICON" "$VM"
        ;;
    *)
        printf '{"text":"%s  Maya VM off","tooltip":"%s %s\\nLeft-click: start and open console  •  Right-click: virt-manager","class":"off"}\n' "$ICON" "$VM" "$state"
        ;;
esac

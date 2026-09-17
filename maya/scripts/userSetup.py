# Maya userSetup (linked into ~/maya/<ver>/scripts/ by bootstrap.sh setup_mcp_maya).
# Auto-starts the maya-mcp bridge (~/dev/maya-mcp/maya_bridge.py) so Claude
# Code's `maya` MCP server can drive this session: 127.0.0.1:7777.
# Importing maya_bridge inside Maya starts it; deferred until the UI is up.
import os
import sys

import maya.utils

_BRIDGE_DIR = os.path.join(os.path.expanduser("~"), "dev", "maya-mcp")


def _start_mcp_bridge():
    try:
        if _BRIDGE_DIR not in sys.path:
            sys.path.append(_BRIDGE_DIR)
        import maya_bridge  # noqa: F401  (auto-starts when inside Maya)
    except Exception as e:  # never break Maya startup over this
        print("maya-mcp bridge not started:", e)


maya.utils.executeDeferred(_start_mcp_bridge)

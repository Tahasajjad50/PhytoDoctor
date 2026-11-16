import sys
import os
import inspect

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from app.main import app

FRAMEWORK_ROUTES = {'openapi', 'swagger_ui_html', 'swagger_ui_redirect', 'redoc_html'}

def inspect_routes():
    inventory = []
    seen_signatures = set()
    
    for r in app.routes:
        if r.name in FRAMEWORK_ROUTES:
            continue
        methods = [m for m in getattr(r, 'methods', []) if m not in ('HEAD', 'OPTIONS')]
        if not methods:
            continue
        
        endpoint_fn = getattr(r, 'endpoint', None)
        module_name = endpoint_fn.__module__ if endpoint_fn else "app"
        func_name = r.name
        
        # Analyze parameters for dependencies
        auth_level = "Public"
        if endpoint_fn:
            sig = inspect.signature(endpoint_fn)
            params_str = str(sig.parameters)
            if "require_owner" in params_str:
                auth_level = "OWNER (CEO Only)"
            elif "require_admin" in params_str:
                auth_level = "ADMIN (Owner or Manager)"
            elif "get_current_user" in params_str:
                auth_level = "AUTHENTICATED (Any Role)"
            elif "x_admin_key" in params_str:
                auth_level = "SYSTEM (X-Admin-Key Header)"
            elif "current_user" in params_str:
                auth_level = "AUTHENTICATED"
        
        # Check for trailing slash duplicates
        sig_tuple = (methods[0], r.path.rstrip('/'))
        is_alias = False
        if r.path != '/' and r.path.endswith('/') and sig_tuple in seen_signatures:
            is_alias = True
        seen_signatures.add(sig_tuple)
        
        inventory.append({
            "method": methods[0],
            "path": r.path,
            "handler": func_name,
            "module": module_name.replace("app.api.v1.", "").replace("app.", ""),
            "auth": auth_level,
            "is_alias": is_alias,
        })
    
    print(f"Total Routes Registered (including aliases): {len(inventory)}")
    distinct = [x for x in inventory if not x['is_alias']]
    print(f"Total Unique Business Endpoints: {len(distinct)}")
    print(f"Trailing Slash Route Aliases: {len(inventory) - len(distinct)}")
    print("=" * 80)
    for idx, item in enumerate(distinct, 1):
        print(f"{idx:02d}. {item['method']:<6} {item['path']:<50} | {item['module']:<12} | {item['auth']}")
        
if __name__ == "__main__":
    inspect_routes()

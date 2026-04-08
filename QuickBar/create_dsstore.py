from ds_store import DSStore
import os

dmg_path = "/Volumes/QuickBar"
ds_store_path = os.path.join(dmg_path, ".DS_Store")

with DSStore.open(ds_store_path, "w+") as ds:
    ds["."]["bwsp"] = {
        'ShowStatusBar': False,
        'ShowTabView': False,
        'ShowToolbar': False,
        'ShowPathbar': False,
        'ShowSidebar': False,
        'ContainerShowSidebar': False,
        'SidebarWidth': 0,
        'arrangeBy': 'none',
        'IconViewSettings': {
            'iconSize': 128,
            'textSize': 14,
            'labelOnBottom': True,
            'arrangeBy': 'none',
            'gridOffsetX': 10,
            'gridOffsetY': 10,
            'gridSpacing': 100,
            'usesRelativeDates': False,
            'backgroundType': 0
        },
        'Globals': {
            'ShowStatusBar': False,
            'ShowTabView': False,
            'ShowToolbar': False,
            'ShowPathbar': False,
            'ShowSidebar': False,
            'ContainerShowSidebar': False,
            'SidebarWidth': 0
        },
        'WindowBounds': {
            'origin': {'x': 400, 'y': 200},
            'size': {'width': 540, 'height': 360}
        }
    }

    ds["QuickBar.app"]["icgp"] = {'x': 140, 'y': 160}
    ds["Applications"]["icgp"] = {'x': 400, 'y': 160}

print("DS_Store created successfully")

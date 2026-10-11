"""Install the independent mod into the detected TF3 user profile."""
import json
import shutil
from datetime import datetime
from pathlib import Path

root = Path(__file__).resolve().parent
matches = sorted((Path.home()/'Library/Application Support/Steam/userdata').glob('*/3493540/local'))
if len(matches) != 1:
    raise SystemExit('Cannot uniquely identify TF3 profile. Copy mod/ to your userdata mods/linnan_bulb_cockpit directory.')
destination = matches[0]/'mods/linnan_bulb_cockpit'
if destination.exists():
    metadata = json.loads((destination/'mod.json').read_text())
    if metadata.get('modId') != 'linnan_bulb_cockpit':
        raise SystemExit('Refusing to replace a different mod.')
    backup = root/'previous-install-backups'/datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    shutil.copytree(destination, backup)
shutil.copytree(root/'mod', destination, dirs_exist_ok=True)
print('Installed: '+str(destination))
print('Save and fully restart TF3, then load the save with In-Game Route Display / 游戏线路显示 enabled.')

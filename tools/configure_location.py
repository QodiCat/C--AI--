"""Configure foreground location permissions after generating Flutter platforms."""
from pathlib import Path
import plistlib

ROOT = Path(__file__).resolve().parent.parent / "app"
manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
if manifest.exists():
    text = manifest.read_text()
    permission = "android.permission.ACCESS_COARSE_LOCATION"
    if permission not in text:
        text = text.replace("    <application", f'    <uses-permission android:name="{permission}" />\n    <application', 1)
        manifest.write_text(text)
    print("Android: foreground approximate location permission configured")
else:
    print("Android: platform not generated; run again after flutter create")

info = ROOT / "ios/Runner/Info.plist"
if info.exists():
    with info.open("rb") as source:
        data = plistlib.load(source)
    data["NSLocationWhenInUseUsageDescription"] = "获取当前位置的天气，用于生成今日穿搭推荐。"
    with info.open("wb") as destination:
        plistlib.dump(data, destination, sort_keys=False)
    podfile = ROOT / "ios/Podfile"
    if podfile.exists():
        text = podfile.read_text()
        if "BYPASS_PERMISSION_LOCATION_ALWAYS=1" not in text:
            anchor = "flutter_additional_ios_build_settings(target)"
            if anchor not in text:
                raise SystemExit("iOS: Podfile uses a custom layout; configure BYPASS_PERMISSION_LOCATION_ALWAYS=1 manually")
            text = text.replace(anchor, anchor + "\n    if target.name == 'geolocator_apple'\n      target.build_configurations.each do |config|\n        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']\n        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] << 'BYPASS_PERMISSION_LOCATION_ALWAYS=1'\n      end\n    end", 1)
            podfile.write_text(text)
    print("iOS: foreground location permission configured")
else:
    print("iOS: platform not generated; run again after flutter create")

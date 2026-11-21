#!/usr/bin/env bash
# Architecture rules from docs/spec-v2.md A2/A3. Exit 1 on any violation.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
bad() { echo "FAIL: $1"; fail=1; }
src() { grep -rnE --include='*.dart' "$@"; }

src 'setState\s*\(|StatefulBuilder' lib/ && bad 'setState/StatefulBuilder in lib/'
src 'showDialog|showModalBottomSheet|ScaffoldMessenger|SnackBar|BackdropFilter|ImageFilter\.blur|ShaderMask|FragmentProgram' lib/ \
  && bad 'dialogs/snackbars must be routes or inline state; glass is never faked'
src "package:flutter/(material|cupertino)\.dart" lib/ test/ \
  && bad 'deprecated import; use package:material_ui/material_ui.dart'

# StatefulWidget is allowed only to own an AnimationController.
src -l 'extends StatefulWidget' lib/ \
  | grep -v -e '^lib/features/game/presentation/widgets/spin_stage.dart$' \
  && bad 'StatefulWidget outside the allowlist'

src -l "package:adaptive_platform_ui" lib/ | grep -v '^lib/platform/' \
  && bad 'adaptive_platform_ui may only be imported under lib/platform/'
src 'Adaptive(App|Scaffold|AlertDialog|SnackBar|BlurView|Button|PopupMenuButton|ContextMenu|Card)\b|Ios26NativeBlurView|IOS26AlertDialog' lib/ \
  && bad 'only IOS26Button (and, from Phase 3, AdaptiveSwitch/AdaptiveSlider) may be used from adaptive_platform_ui'

# lib/platform imports adaptive_platform_ui only with an allow-listed `show`.
allow='IOS26Button|IOS26ButtonStyle|SFSymbol|AdaptiveSwitch|AdaptiveSlider'
while IFS= read -r f; do
  imp=$(grep -A1 "^import 'package:adaptive_platform_ui" "$f" | tr '\n' ' ')
  case "$imp" in
    *" show "*) ;;
    *) bad "$f: adaptive_platform_ui import needs a show list"; continue ;;
  esac
  for n in $(echo "$imp" | sed -E 's/.* show //; s/;.*//' | tr ',' ' '); do
    echo "$n" | grep -qE "^($allow)$" || bad "$f: $n not on the adaptive_platform_ui allow-list"
  done
done < <(grep -rl --include='*.dart' "^import 'package:adaptive_platform_ui" lib/platform 2>/dev/null)

layers=$(find lib/features -type d \( -name domain -o -name data -o -name bloc -o -name cubit \) 2>/dev/null)
[ -n "$layers" ] && src 'BuildContext' $layers && bad 'BuildContext in domain/data/bloc/cubit'

domain=$(find lib/features -type d -name domain 2>/dev/null)
[ -n "$domain" ] && src "dart:ui|package:(flutter|sqflite|get_it|shared_preferences)" $domain && bad 'domain must be pure Dart'

pres=$(find lib/features -type d -name presentation 2>/dev/null)
[ -n "$pres" ] && src "^import .*/data/" $pres && bad 'presentation must not import data'

[ "$fail" -eq 0 ] && echo 'check_rules: OK'
exit "$fail"

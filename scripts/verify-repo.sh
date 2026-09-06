#!/usr/bin/env bash
# Automated consistency/regression checks for the language-learning skill pack.
# No app/build/CI exists for this repo (it's SKILL.md prompt files, a JSON config,
# and a static HTML dashboard), so this script is the repeatable "test suite":
# it catches cross-file consistency bugs (the kind that can't be caught by just
# reading one file at a time) without needing a live Claude conversation.
#
# Usage: ./scripts/verify-repo.sh
# Exits 0 if everything passes, 1 on the first category with a failure (each
# category prints all its own failures before the script moves on or stops).

set -uo pipefail
cd "$(dirname "$0")/.."

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
FAIL=0
pass() { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; FAIL=1; }
section() { echo -e "\n${YELLOW}== $1 ==${NC}"; }

SKILLS=(daily-language-practice language-weekend-review language-sunday-writing-listening learning-setup)
SCHEDULED_SKILLS=(daily-language-practice language-weekend-review language-sunday-writing-listening)

# ---------------------------------------------------------------------------
section "1. Structure: skill folders, SKILL.md, and .skill zip sync"
# ---------------------------------------------------------------------------
for d in "${SKILLS[@]}"; do
  if [[ ! -f "$d/SKILL.md" ]]; then
    fail "$d/SKILL.md missing"
    continue
  fi
  if [[ ! -f "$d.skill" ]]; then
    fail "$d.skill zip missing"
    continue
  fi
  if diff -q <(unzip -p "$d.skill" "$d/SKILL.md" 2>/dev/null) "$d/SKILL.md" >/dev/null 2>&1; then
    pass "$d: SKILL.md present, $d.skill zip matches"
  else
    fail "$d.skill is stale (doesn't match $d/SKILL.md — regenerate with: zip -0 -r $d.skill $d/)"
  fi
done

# ---------------------------------------------------------------------------
section "2. Frontmatter: name: matches folder name"
# ---------------------------------------------------------------------------
for d in "${SKILLS[@]}"; do
  [[ -f "$d/SKILL.md" ]] || continue
  declared=$(grep -m1 '^name:' "$d/SKILL.md" | sed 's/^name: *//')
  if [[ "$declared" == "$d" ]]; then
    pass "$d: name: $declared"
  else
    fail "$d/SKILL.md declares name: '$declared', expected '$d'"
  fi
done

# ---------------------------------------------------------------------------
section "3-7. Config validity + cross-file consistency (learning-config.json / SKILL.md / dashboard)"
# ---------------------------------------------------------------------------
python3 - <<'PYEOF'
import json, re, sys, glob

ok = True
def fail(msg):
    global ok
    print(f"  \033[0;31m✗\033[0m {msg}")
    ok = False
def passed(msg):
    print(f"  \033[0;32m✓\033[0m {msg}")

# --- 3. config validity ---
try:
    with open("learning-config.json") as f:
        cfg = json.load(f)
    passed("learning-config.json is valid JSON")
except Exception as e:
    fail(f"learning-config.json failed to parse: {e}")
    sys.exit(1)

required_top = ["schemaVersion","targetLanguage","targetLanguageCode","baseLanguage",
                "baseLanguageCode","cefrLevel","targetFlagEmoji","baseFlagEmoji",
                "notesFolderName","notePrefixes","grammarStructures","mistakeCategories",
                "contentSources","contentSourceSearchInstruction","createdAt","updatedAt"]
missing = [k for k in required_top if k not in cfg]
if missing:
    fail(f"learning-config.json missing top-level keys: {missing}")
else:
    passed("learning-config.json has all required top-level keys")

required_prefixes = ["conversation","quiz","writingListening"]
missing_p = [k for k in required_prefixes if k not in cfg.get("notePrefixes", {})]
if missing_p:
    fail(f"learning-config.json notePrefixes missing: {missing_p}")
else:
    passed("learning-config.json notePrefixes has all 3 entries")

# --- 4. variable-declaration consistency in the 3 scheduled SKILL.md files ---
scheduled = ["daily-language-practice", "language-weekend-review", "language-sunday-writing-listening"]
for d in scheduled:
    path = f"{d}/SKILL.md"
    try:
        text = open(path).read()
    except FileNotFoundError:
        fail(f"{path} not found")
        continue
    # Everything after the "0) LOAD LEARNING CONFIG" step's declared list, up to the next blank-line gap,
    # is where {vars} get declared as "- `{var}` ..."
    m = re.search(r"0\) LOAD LEARNING CONFIG.*?(?=\n\n\S|\Z)", text, re.S)
    declared_block = m.group(0) if m else ""
    declared = set(re.findall(r"`\{(\w+)\}`", declared_block))
    # every {snake_case_var} used anywhere in the body (excluding the declared block itself)
    body = text[m.end():] if m else text
    used = set(re.findall(r"\{([a-z][a-z0-9_]*)\}", body))
    undeclared = sorted(used - declared)
    if undeclared:
        fail(f"{path}: uses {{var}} placeholder(s) not declared in Step 0: {undeclared}")
    else:
        passed(f"{path}: all used {{var}} placeholders are declared in Step 0 ({len(declared)} declared)")

# --- 5. grammar-structure key consistency (the "Nebensätze" bug class) ---
grammar_structures = cfg.get("grammarStructures", [])
redundant_terms = {"nebensätze", "nebensaetze", "subordinate clauses", "complex sentences"}
dupes = [g for g in grammar_structures if g.strip().lower() in redundant_terms]
if dupes:
    fail(f"learning-config.json grammarStructures duplicates the fixed 'Complex sentences (subordinate clauses)' row: {dupes}")
else:
    passed("learning-config.json grammarStructures has no entry duplicating 'Complex sentences (subordinate clauses)'")

try:
    dash = open("dashboard-template.html").read()
except FileNotFoundError:
    dash = ""
    fail("dashboard-template.html not found")

m = re.search(r"const b2 = \{([^}]*)\};", dash)
if m:
    b2_keys = re.findall(r"'([^']+)':\s*0", m.group(1))
    fixed_row = "Complex sentences (subordinate clauses)"
    orphan_keys = [k for k in b2_keys if k != fixed_row and k not in grammar_structures]
    if orphan_keys:
        fail(f"dashboard-template.html b2 chart object has key(s) not in config's grammarStructures and not the fixed row: {orphan_keys}")
    else:
        passed("dashboard-template.html b2 chart keys all trace back to grammarStructures or the fixed row")
    missing_keys = [g for g in grammar_structures if g not in b2_keys]
    if missing_keys:
        fail(f"config grammarStructures has entries the dashboard's b2 chart doesn't track (will silently show 0): {missing_keys}")
    else:
        passed("every config grammarStructures entry has a matching dashboard b2 chart key")
else:
    fail("could not find `const b2 = {...}` in dashboard-template.html")

# --- 6. mistake-category set consistency ---
m = re.search(r"const CATEGORY_COLORS = \{(.*?)\};", dash, re.S)
if m:
    color_keys = set(re.findall(r"'([^']+)':\s*'#", m.group(1))) - {"Uncategorized"}
    config_cats = set(cfg.get("mistakeCategories", []))
    if color_keys != config_cats:
        only_dash = sorted(color_keys - config_cats)
        only_cfg = sorted(config_cats - color_keys)
        fail(f"CATEGORY_COLORS vs mistakeCategories mismatch. Only in dashboard: {only_dash}. Only in config: {only_cfg}")
    else:
        passed("dashboard CATEGORY_COLORS keys exactly match config mistakeCategories")
else:
    fail("could not find `const CATEGORY_COLORS = {...}` in dashboard-template.html")

# --- 7. table-header contract between daily-language-practice's note template and the dashboard parser ---
try:
    daily = open("daily-language-practice/SKILL.md").read()
except FileNotFoundError:
    daily = ""
    fail("daily-language-practice/SKILL.md not found")

header_checks = [
    ("Word/Plural (nouns table)", r"<th>Word</th><th>Plural</th>", "header.includes('Word') && header.includes('Plural')"),
    ("Adjective (adjectives table)", r"<th>Adjective</th>", "header[0] === 'Adjective'"),
    ("Infinitive (verbs table)", r"<th>Infinitive</th>", "header[0] === 'Infinitive'"),
    ("Idiom (idioms table)", r"<th>Idiom</th>", "header[0] === 'Idiom'"),
    ("Category/Wrong (mistakes table)", r"<th>Category</th><th>Wrong</th>", "header.includes('Category') && header.includes('Wrong')"),
    ("Metric (statistics table)", r"<th>Metric</th>", "header[0] === 'Metric'"),
]
for label, pattern, dash_expr in header_checks:
    in_template = re.search(pattern, daily) is not None
    in_dashboard = dash_expr in dash
    if in_template and in_dashboard:
        passed(f"table-header contract OK: {label}")
    elif not in_template:
        fail(f"daily-language-practice/SKILL.md note template no longer has the expected header for: {label}")
    else:
        fail(f"dashboard-template.html parseNote() no longer detects: {label}")

sys.exit(0 if ok else 1)
PYEOF
[[ $? -eq 0 ]] || FAIL=1

# ---------------------------------------------------------------------------
section "8. No leftover hardcoded German/B2 literals outside allowlisted files"
# ---------------------------------------------------------------------------
LITERALS='Deutsch B2|Deutsch lernen B2|🇦🇹|B2-Umformulierung|Sonstiges|Unbekannt'
HITS=$(grep -rnE "$LITERALS" daily-language-practice/ language-weekend-review/ language-sunday-writing-listening/ learning-setup/ 2>/dev/null | grep -v '^learning-setup/SKILL.md:')
if [[ -z "$HITS" ]]; then
  pass "no stray hardcoded German/B2 literals in the 4 skill folders (outside learning-setup's documented example text)"
else
  fail "stray hardcoded literals found:"
  echo "$HITS" | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
section "9. Dashboard JS syntax"
# ---------------------------------------------------------------------------
python3 -c "
html = open('dashboard-template.html').read()
script = html.split('<script>',1)[1].rsplit('</script>',1)[0]
open('/tmp/verify-repo-dash.js','w').write(script)
"
if command -v osascript >/dev/null 2>&1; then
  RESULT=$(osascript -l JavaScript -e '
    var fs = $.NSString.stringWithContentsOfFileEncodingError($("/tmp/verify-repo-dash.js"), $.NSUTF8StringEncoding, null);
    try { eval("(function(){" + fs.js + "})"); "OK"; } catch(e) { "ERROR: " + e; }
  ' 2>&1)
  if [[ "$RESULT" == "OK" ]]; then
    pass "dashboard-template.html <script> block parses cleanly"
  else
    fail "dashboard-template.html <script> block has a syntax error: $RESULT"
  fi
elif command -v node >/dev/null 2>&1; then
  if node --check /tmp/verify-repo-dash.js 2>/tmp/verify-repo-dash.err; then
    pass "dashboard-template.html <script> block parses cleanly"
  else
    fail "dashboard-template.html <script> block has a syntax error: $(cat /tmp/verify-repo-dash.err)"
  fi
else
  echo -e "  ${YELLOW}skipped${NC} (no osascript or node available to check JS syntax)"
fi
rm -f /tmp/verify-repo-dash.js /tmp/verify-repo-dash.err

# ---------------------------------------------------------------------------
section "10. README/CHANGELOG don't reference old skill names outside history"
# ---------------------------------------------------------------------------
OLD_NAMES='daily-german-practice|german-weekend-review|german-sunday-schreiben-und-hoeren'
README_HITS=$(grep -nE "$OLD_NAMES" README.md 2>/dev/null)
if [[ -z "$README_HITS" ]]; then
  pass "README.md has no references to the old skill names"
else
  fail "README.md still references old skill names:"
  echo "$README_HITS" | sed 's/^/      /'
fi
# CHANGELOG.md is allowed to mention old names under historical version headers (< 2.0.0) and in the
# 2.0.0 rename note itself; only flag if they appear with no changelog context at all (best-effort: just report count for visibility).
CHANGELOG_COUNT=$(grep -cE "$OLD_NAMES" CHANGELOG.md 2>/dev/null || true)
echo -e "  ${YELLOW}info${NC} CHANGELOG.md references old skill names $CHANGELOG_COUNT time(s) (expected: historical entries + the 2.0.0 rename note)"

# ---------------------------------------------------------------------------
echo
if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}All automated checks passed.${NC}"
  exit 0
else
  echo -e "${RED}One or more automated checks failed. See ✗ lines above.${NC}"
  exit 1
fi

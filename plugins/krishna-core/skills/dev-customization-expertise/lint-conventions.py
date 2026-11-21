"""WD house-convention lint over the lines a branch adds.

Usage:
  git -C <repo> diff origin/develop -U0 -- "*.cs" "*.vb" ":!*.Designer.cs" ":!*.designer.cs" ":!*.Designer.vb" > pr.diff
  python -I lint-conventions.py pr.diff

Prints each hit as file:line  rule  code. A hit is not always wrong (a value type's .ToString(),
a StringComparer in a HashSet, a sibling pattern the method already uses); every remaining hit
needs a reason. Rules come from reviewer comments on unify-enterprise PRs (see SKILL.md table).
"""
import re
import sys

RULES = [
    ("IsNullOrBlank", r"\b[Ss]tring\.IsNullOr(Empty|WhiteSpace)\(|(==|!=|<>)\s*\"\"|\s=\s\"\"\s*(Then|AndAlso|OrElse)"),
    ("ToEqual", r"\b[Ss]tring\.Equals\(|\.Equals\(\"|StringComparison\.OrdinalIgnoreCase\)|\.ToUpper\(\)\s*==|\.ToLower\(\)\s*=="),
    ("ToStr/ToInt", r"Convert\.To(Int16|Int32|Int64|Decimal|Double|Boolean)\(|\b(int|long|decimal|double|Integer|Long|Decimal)\.Parse\("),
    ("ToStr (.ToString)", r"\.ToString\(\)"),
    ("DAL via factory", r"new \w+DAL\(\)"),
    ("message text as control flow", r"(Message|message|msg)\w*\.Contains\(\"|Contains\(\"\d{3}\"\)"),
    ("empty catch", r"catch\s*(\(\s*\w*\s*\w*\s*\))?\s*\{\s*\}"),
    ("SQL Server 2005", r"DECLARE\s+@\w+\s+\w+(\(\d+\))?\s*=|\bMERGE\s+\w|\bIIF\(|STRING_SPLIT\(|TRY_CONVERT\(|STRING_AGG\("),
    ("exact node check (IsCustomizationNodeEnabledForProfile)", r"CustomizationNode\.Contains\(\s*CustomizationConstant\.\w+\s*(\+|&)"),
]


def main(path):
    current, line_no, hits = None, 0, 0
    with open(path, encoding="utf-8", errors="replace") as diff:
        for raw in diff:
            if raw.startswith("+++ "):
                current = raw[6:].strip()
                continue
            m = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)", raw)
            if m:
                line_no = int(m.group(1))
                continue
            if raw.startswith("-") or not raw.startswith("+"):
                continue
            code = raw[1:].rstrip("\r\n")
            stripped = code.strip()
            if not stripped.startswith(("//", "'", "*", "///")):
                for name, pattern in RULES:
                    if re.search(pattern, code):
                        hits += 1
                        print(f"{current}:{line_no}  [{name}]  {stripped[:160]}")
            line_no += 1
    print(f"\n{hits} hit(s)")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    main(sys.argv[1])

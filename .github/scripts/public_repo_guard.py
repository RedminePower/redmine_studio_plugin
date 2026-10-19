#!/usr/bin/env python3
"""公開リポジトリに書いてはいけない情報の混入を検査する。

このリポジトリは公開されている。次の 2 種類を検査する。

1. テスト環境に固有の値（test/ 配下のファイル、PR のタイトル/本文、コミットメッセージ）
   接続先のポート・版付きのコンテナ名/サブディレクトリ・API キー・管理者の認証情報。
   パターンはこのファイルに書いてある（値そのものではなく形で検出する）。

2. 追加の禁止パターン（リポジトリの全ファイル、PR のタイトル/本文、コミットメッセージ）
   GitHub の Secret `PUBLIC_REPO_GUARD_PATTERNS`（1 行 1 正規表現）から読む。
   手元では環境変数 PUBLIC_REPO_GUARD_PATTERNS か、リポジトリ直下の
   `.public-repo-guard-patterns` に置く。一致した文字列はログに出さない（場所だけを出す）。

使い方:
    python .github/scripts/public_repo_guard.py files
    python .github/scripts/public_repo_guard.py text "PR title/body" < text.txt

誤検知の行は、その行に `public-repo-guard: allow` と書くと検査から外れる（ファイルのみ）。
"""

import os
import re
import subprocess
import sys

ALLOW_MARK = "public-repo-guard: allow"

# (名前, 正規表現, 対象) 対象: "test" = test/ 配下のファイルとテキスト, "test-file" = test/ 配下のファイルのみ
ENV_RULES = [
    ("接続先のポート番号", re.compile(r"\b(?:localhost|127\.0\.0\.1|host\.docker\.internal)\s*:\s*\d+"), "test"),
    ("版付きのコンテナ名/フォルダ名", re.compile(r"\bredmine_\d+\.\d+"), "test"),
    ("版付きのサブディレクトリ", re.compile(r"/redmine_\d{2,}\b"), "test"),
    ("管理者の認証情報", re.compile(r"PSCredential\(\s*['\"]admin['\"]"), "test"),
    ("管理者の認証情報", re.compile(r"\badmin\s*/\s*[A-Za-z0-9]"), "test"),
    ("管理者の認証情報", re.compile(r"ログイン\s*[:：]\s*admin\b"), "test"),
    # コミットメッセージにはコミットの SHA が出てくるため、API キー形の検査はファイルのみ
    ("API キー（40 桁の英数字）", re.compile(r"\b[0-9a-f]{40}\b"), "test-file"),
]


def load_private_patterns():
    raw = os.environ.get("PUBLIC_REPO_GUARD_PATTERNS", "")
    if not raw.strip():
        path = os.path.join(repo_root(), ".public-repo-guard-patterns")
        if os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                raw = f.read()
    patterns = []
    for line in raw.splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            patterns.append(re.compile(line, re.IGNORECASE))
    return patterns


def repo_root():
    return subprocess.run(
        ["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=True
    ).stdout.strip()


def check_lines(label, lines, in_test, is_file, private_patterns):
    problems = []
    for no, line in enumerate(lines, 1):
        if is_file and ALLOW_MARK in line:
            continue
        for i, pattern in enumerate(private_patterns, 1):
            if pattern.search(line):
                # 一致した文字列も行の内容も出さない
                problems.append(f"{label}:{no}: 追加の禁止パターン {i}")
        if in_test:
            for name, rule, scope in ENV_RULES:
                if scope == "test-file" and not is_file:
                    continue
                m = rule.search(line)
                if m:
                    problems.append(f"{label}:{no}: {name}: {m.group(0)}")
    return problems


def check_files(private_patterns):
    root = repo_root()
    files = subprocess.run(
        ["git", "ls-files", "-z"], capture_output=True, text=True, check=True, cwd=root
    ).stdout.split("\0")
    problems = []
    for rel in filter(None, files):
        try:
            with open(os.path.join(root, rel), encoding="utf-8") as f:
                lines = f.read().splitlines()
        except (UnicodeDecodeError, FileNotFoundError, IsADirectoryError):
            continue  # バイナリ等
        in_test = rel.startswith("test/")
        problems += check_lines(rel, lines, in_test, True, private_patterns)
    return problems


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("files", "text"):
        print(__doc__)
        return 2
    private_patterns = load_private_patterns()
    if not private_patterns:
        print("::warning::PUBLIC_REPO_GUARD_PATTERNS が未設定のため、追加の禁止パターンは検査していません")

    if sys.argv[1] == "files":
        problems = check_files(private_patterns)
    else:
        label = sys.argv[2] if len(sys.argv) > 2 else "text"
        lines = sys.stdin.read().splitlines()
        problems = check_lines(label, lines, True, False, private_patterns)

    if problems:
        print("公開リポジトリに書いてはいけない情報が見つかりました（test/README.md 参照）:")
        for p in problems:
            print(f"  {p}")
        print("具体値は test/README.md のプレースホルダに置き換え、値は test/env.local.json に置いてください。")
        print("PR のタイトル/本文の場合は編集して取り除いてください（編集履歴に残るため、旧版の削除も必要です）。")
        return 1
    print("OK: 公開リポジトリに書いてはいけない情報は見つかりませんでした")
    return 0


if __name__ == "__main__":
    sys.exit(main())

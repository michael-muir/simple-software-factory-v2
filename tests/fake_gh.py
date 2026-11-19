#!/usr/bin/env python3
"""A stand-in for the `gh` CLI, for tests. State lives in $FAKE_GH_STATE (JSON).

It supports exactly the gh calls factory/bin/board makes. Every call is also
appended to state["calls"] so tests can assert on what the factory did.
"""

import json
import os
import sys
import time

STATE = os.environ["FAKE_GH_STATE"]


def load():
    with open(STATE) as f:
        return json.load(f)


def save(s):
    with open(STATE, "w") as f:
        json.dump(s, f, indent=2)


def opt(args, name, default=None):
    if name in args:
        return args[args.index(name) + 1]
    return default


def now():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def body_from(args):
    if opt(args, "--body-file") == "-":
        return sys.stdin.read()
    return opt(args, "--body", "")


def main(args):
    s = load()
    s.setdefault("calls", []).append(args)
    me = s.get("user", "operator")
    out = ""
    a = args
    if a[:2] == ["api", "user"]:
        out = me
    elif a[:2] == ["repo", "view"]:
        out = json.dumps({"nameWithOwner": "acme/app",
                          "defaultBranchRef": {"name": s.get("default_branch", "main")}})
    elif a[:2] == ["label", "create"]:
        s.setdefault("labels", []).append(a[2])
    elif a[:2] == ["issue", "view"]:
        i = s["issues"].get(a[2])
        if not i:
            print(f"no issue {a[2]}", file=sys.stderr)
            save(s)
            sys.exit(1)
        out = json.dumps({
            "number": int(a[2]), "title": i["title"], "body": i.get("body", ""),
            "author": {"login": i.get("author", "alice")},
            "labels": [{"name": n} for n in i.get("labels", [])],
            "state": i.get("state", "OPEN"), "url": f"https://github.com/acme/app/issues/{a[2]}",
            "comments": i.get("comments", []),
        })
    elif a[:2] == ["issue", "list"]:
        label = opt(a, "--label")
        out = json.dumps([
            {"number": int(n), "title": i["title"], "labels": [{"name": l} for l in i.get("labels", [])]}
            for n, i in s["issues"].items()
            if i.get("state", "OPEN") == "OPEN" and label in i.get("labels", [])
        ])
    elif a[:2] == ["issue", "comment"]:
        s["issues"][a[2]].setdefault("comments", []).append(
            {"author": {"login": me}, "body": body_from(a), "createdAt": now()})
    elif a[:2] == ["issue", "edit"]:
        i = s["issues"][a[2]]
        labels = i.setdefault("labels", [])
        if "--add-label" in a and opt(a, "--add-label") not in labels:
            labels.append(opt(a, "--add-label"))
        if "--remove-label" in a and opt(a, "--remove-label") in labels:
            labels.remove(opt(a, "--remove-label"))
    elif a[:2] == ["issue", "create"]:
        n = str(max([int(k) for k in s["issues"]] or [0]) + 1)
        s["issues"][n] = {"title": opt(a, "--title"), "body": body_from(a), "author": me,
                          "labels": [opt(a, "--label")], "comments": []}
        out = f"https://github.com/acme/app/issues/{n}"
    elif a[:2] == ["pr", "create"]:
        n = str(100 + len(s.setdefault("prs", {})) + 1)
        s["prs"][n] = {"head": opt(a, "--head"), "base": opt(a, "--base"), "title": opt(a, "--title"),
                       "body": body_from(a), "state": "OPEN", "draft": "--draft" in a, "comments": []}
        out = f"https://github.com/acme/app/pull/{n}"
    elif a[:2] == ["pr", "view"]:
        p = s["prs"][a[2]]
        out = json.dumps({"number": int(a[2]), "state": p["state"], "isDraft": p["draft"],
                          "url": f"https://github.com/acme/app/pull/{a[2]}"})
    elif a[:2] == ["pr", "ready"]:
        s["prs"][a[2]]["draft"] = False
    elif a[:2] == ["pr", "comment"]:
        s["prs"][a[2]]["comments"].append(body_from(a))
    elif a[:2] == ["pr", "close"]:
        s["prs"][a[2]]["state"] = "CLOSED"
    elif a[:2] == ["pr", "merge"]:
        if s.get("merge_fails"):
            print("Required status check is failing", file=sys.stderr)
            save(s)
            sys.exit(1)
        s["prs"][a[2]]["state"] = "MERGED"
        s["prs"][a[2]]["method"] = a[3]
    else:
        print(f"fake gh: unsupported call {a}", file=sys.stderr)
        save(s)
        sys.exit(1)
    save(s)
    if out:
        print(out)


if __name__ == "__main__":
    main(sys.argv[1:])

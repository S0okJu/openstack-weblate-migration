#!/usr/bin/env python3
"""Aggregate migration_projects.sh batch results into one status report.

Reads:
  - logs/summary.tsv, the per (project, version) run verdict that
    migration_projects.sh appends to on every run (completed_at,
    project, version, exit_code, run_id, started_at).
  - <workspace>/projects/<project>/result.jsonl, the per (project,
    category, component, locale) accuracy-check events that
    common/weblate_utils.py appends (see migration-status-tracking
    Phase 2 and Phase 5), folded into one merged entry per key by
    common.weblate_utils.reduce_result_events().
  - logs/<project>/project.<run_id>.log, to classify *where* a failed
    run stopped (clone / POT generation / Weblate component creation
    / accuracy check), by finding the last stage marker
    migration_resources.sh printed for that version before it exited
    (most stages via pretty-printer.sh's stage(), which prints
    "# <title>"; env_check/cleanup are plain "[INFO] <text>" lines
    since they aren't wrapped in stage()/endstage() - see
    batch-execution-readability Phase 1).

Prints a project x version x component x locale status table (or CSV)
so "how far did the migration get, and where did it fail" can be
answered without opening every logs/<project>/error.*.log by hand.
"""
import argparse
import csv
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / 'common'))
from weblate_utils import (  # noqa: E402
    load_result_events, reduce_result_events)

# Ordered (stage_key, marker_prefix, display_label) triples, in the
# same order migration_resources.sh prints them. classify_stage() finds
# the *last* one reached for a given version before the run's exit
# code was captured, i.e. the stage that was in progress when it died.
STAGE_MARKERS = [
    ('env_check', '[INFO] Check variables', '환경변수 확인 실패'),
    ('setup', '# Setup environment and prepare workspace', '환경설정 실패'),
    ('clone', '# Clone ', 'clone 실패'),
    ('pot', '# Generate POT and export translations from Zanata',
     'POT 생성/Zanata export 실패'),
    ('weblate_component', '# Create Weblate components',
     'Weblate 컴포넌트 생성 실패'),
    ('accuracy', '# Start Accuracy Test', '정합성 불일치'),
    ('cleanup', '[INFO] Clean up workspace directory', '성공(정리 단계 도달)'),
]
STAGE_LABELS = {key: label for key, _, label in STAGE_MARKERS}
UNKNOWN_STAGE = 'unknown'
STAGE_LABELS[UNKNOWN_STAGE] = '알 수 없음 (로그 확인 필요)'

# The merged entry's 'status' field (derived by
# common/weblate_utils.py reduce_result_events) can be 'pass', 'fail',
# or 'incomplete' - the latter
# meaning only one of count/detail check ran (e.g. the run was killed
# between them), which is not the same as a confirmed mismatch and
# must not be reported under the same accuracy-mismatch stage label.
ACCURACY_INCOMPLETE_LABEL = '정합성 확인 미완료'


def classify_stage(project_log_path, version):
    """Return the stage key reached last for `version` in the log.

    Only lines prefixed "<version> | " belong to this version's run
    (migration_projects.sh interleaves every version's output into the
    same per-project log file). Returns UNKNOWN_STAGE if the log is
    missing or no known marker was found.
    """
    if not project_log_path.exists():
        return UNKNOWN_STAGE

    prefix = f"{version} | "
    last_stage = None
    with open(project_log_path, encoding='utf-8', errors='replace') as f:
        for line in f:
            if not line.startswith(prefix):
                continue
            content = line[len(prefix):]
            for stage_key, marker, _ in STAGE_MARKERS:
                if content.startswith(marker):
                    last_stage = stage_key
    return last_stage or UNKNOWN_STAGE


def read_summary(logs_dir):
    """Read logs/summary.tsv, keeping only the latest run per
    (project, version) since it's an append-only log across batch
    invocations and re-runs.
    """
    summary_path = Path(logs_dir) / 'summary.tsv'
    latest = {}
    if not summary_path.exists():
        return latest

    with open(summary_path, encoding='utf-8') as f:
        for lineno, line in enumerate(f, start=1):
            line = line.rstrip('\n')
            if not line:
                continue
            parts = line.split('\t')
            if len(parts) != 6:
                print(
                    f"[WARN] {summary_path}:{lineno}: expected 6 "
                    f"tab-separated fields, got {len(parts)} - skipped",
                    file=sys.stderr,
                )
                continue
            (completed_at, project, version, exit_code, run_id,
             started_at) = parts
            try:
                exit_code = int(exit_code)
            except ValueError:
                print(
                    f"[WARN] {summary_path}:{lineno}: non-integer exit "
                    f"code '{exit_code}' - skipped",
                    file=sys.stderr,
                )
                continue
            # Later lines for the same (project, version) overwrite
            # earlier ones, so the last occurrence (most recent run)
            # wins.
            latest[(project, version)] = {
                'completed_at': completed_at,
                'started_at': started_at,
                'exit_code': exit_code,
                'run_id': run_id,
            }
    return latest


def load_result_json(workspace_dir, project):
    """Load and merge project's result.jsonl into the same
    {"project/category/component/locale": entry} shape the old
    single-file result.json used to hold, via
    common.weblate_utils.load_result_events/reduce_result_events.
    """
    path = Path(workspace_dir) / 'projects' / project / 'result.jsonl'
    try:
        return reduce_result_events(load_result_events(path))
    except OSError as e:
        print(
            f"[WARN] Failed to read {path}: {e} - "
            "treating as no accuracy data",
            file=sys.stderr,
        )
        return {}


def zanata_category(version):
    """Match migration_resources.sh's ZANATA_VERSION=${BRANCH_NAME//\\//-}.

    Zanata doesn't allow '/' in version names, so migration_resources.sh
    replaces it with '-' before using the version as the Weblate
    category/result.jsonl 'category' field. summary.tsv keeps the raw
    version (e.g. 'stable/2025.2'), so entries must be looked up by this
    normalized form, not the raw one.
    """
    return version.replace('/', '-')


def _entry_sort_key(entry):
    return (entry.get('component', ''), entry.get('locale', ''))


def _entry_in_run_window(entry, run):
    """True if `entry` (a merged result.jsonl record) was written
    during `run`.

    result.jsonl accumulates across every past run of a project, so a
    (project, category) match alone doesn't mean an entry came from
    the run being reported on - it could be a stale pass/fail left
    over from an earlier attempt at the same version. Both
    entry['checked_at'] (weblate_utils.py, '%Y-%m-%dT%H:%M:%S' local
    time) and run['started_at']/['completed_at'] (migration_projects.sh,
    same format) are naive local timestamps, so a plain string
    comparison is enough to tell whether the entry falls inside this
    run's [started_at, completed_at] window.
    """
    checked_at = entry.get('checked_at', '')
    return run['started_at'] <= checked_at <= run['completed_at']


def _accuracy_rows(project, version, entries):
    """Turn merged result.jsonl entries into report rows for one
    (project, version), with each entry's stage set only when it
    didn't pass.
    """
    rows = []
    for entry in sorted(entries, key=_entry_sort_key):
        status = entry.get('status', 'unknown')
        if status == 'pass':
            stage = '-'
        elif status == 'fail':
            stage = STAGE_LABELS['accuracy']
        else:
            # 'incomplete', or any future/unexpected status value.
            stage = ACCURACY_INCOMPLETE_LABEL
        rows.append({
            'project': project, 'version': version,
            'component': entry.get('component', '-'),
            'locale': entry.get('locale', '-'),
            'status': status, 'stage': stage,
        })
    return rows


def build_report(logs_dir, workspace_dir):
    """Return a list of row dicts: project, version, component, locale,
    status, stage.
    """
    rows = []
    runs = read_summary(logs_dir)
    result_cache = {}

    for (project, version), run in sorted(runs.items()):
        if project not in result_cache:
            result_cache[project] = load_result_json(workspace_dir, project)
        result_data = result_cache[project]

        category = zanata_category(version)
        entries = [
            entry for entry in result_data.values()
            if entry.get('project') == project
            and entry.get('category') == category
            and _entry_in_run_window(entry, run)
        ]

        if run['exit_code'] == 0:
            if not entries:
                rows.append({
                    'project': project, 'version': version,
                    'component': '-', 'locale': '-',
                    'status': 'success', 'stage': '-',
                })
                continue
            rows.extend(_accuracy_rows(project, version, entries))
            continue

        # Non-zero exit code: figure out where it stopped.
        project_log_path = (
            Path(logs_dir) / project / f"project.{run['run_id']}.log"
        )
        stage_key = classify_stage(project_log_path, version)

        if stage_key == 'accuracy' and entries:
            # The run reached the accuracy-check stage this time, so
            # every entry for this (project, version) reflects this
            # run: test_accuracy() exits immediately on the first
            # failing locale, so entries checked before it are real
            # passes and the failing one is the reason for the
            # non-zero exit.
            rows.extend(_accuracy_rows(project, version, entries))
        else:
            # Failed before accuracy checks ever ran (or the log
            # couldn't be classified) - no component/locale to
            # attribute the failure to.
            rows.append({
                'project': project, 'version': version,
                'component': '-', 'locale': '-',
                'status': 'fail', 'stage': STAGE_LABELS[stage_key],
            })

    return rows


def print_table(rows):
    headers = ['project', 'version', 'component', 'locale', 'status', 'stage']
    widths = [len(h) for h in headers]
    for row in rows:
        for i, h in enumerate(headers):
            widths[i] = max(widths[i], len(str(row[h])))

    def fmt_row(values):
        return '  '.join(
            str(v).ljust(widths[i]) for i, v in enumerate(values))

    print(fmt_row(headers))
    print('  '.join('-' * w for w in widths))
    for row in rows:
        print(fmt_row(row[h] for h in headers))

    total = len(rows)
    fail_count = sum(1 for r in rows if r['status'] not in ('success', 'pass'))
    print()
    print(f"{total} rows, {fail_count} failing")
    stage_counts = {}
    for r in rows:
        if r['stage'] != '-':
            stage_counts[r['stage']] = stage_counts.get(r['stage'], 0) + 1
    for stage, count in sorted(stage_counts.items(), key=lambda kv: -kv[1]):
        print(f"  {stage}: {count}")


def print_csv(rows):
    headers = ['project', 'version', 'component', 'locale', 'status', 'stage']
    writer = csv.DictWriter(sys.stdout, fieldnames=headers)
    writer.writeheader()
    for row in rows:
        writer.writerow(row)


def main():
    parser = argparse.ArgumentParser(
        description=(
            'Aggregate migration_projects.sh batch results into a '
            'project x version x component x locale status report.'
        )
    )
    parser.add_argument(
        '--logs-dir', default='logs',
        help="Path to migration_projects.sh's log directory "
             "(default: logs)")
    parser.add_argument(
        '--workspace', default=os.path.expanduser('~/workspace'),
        help='Path to the migration workspace root containing '
             'projects/<project>/result.jsonl (default: ~/workspace)')
    parser.add_argument(
        '--format', choices=['table', 'csv'], default='table',
        help='Output format (default: table)')
    args = parser.parse_args()

    rows = build_report(args.logs_dir, args.workspace)
    if not rows:
        print(
            f"[INFO] No runs found in {args.logs_dir}/summary.tsv",
            file=sys.stderr,
        )
        return

    if args.format == 'csv':
        print_csv(rows)
    else:
        print_table(rows)


if __name__ == '__main__':
    main()

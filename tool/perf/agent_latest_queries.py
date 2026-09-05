#!/usr/bin/env python3
"""Synthetic agent-query experiment; never opens a profile database.

Run from the repository root: python3 tool/perf/agent_latest_queries.py
Uses the checked-in table/index DDL and current repository query. Timings exclude
Dart, JSON decoding, isolate transport, and database queueing. Reopened connections
have cold SQLite page caches, not cold OS caches. Output is JSON on stdout.
"""
import json
import pathlib
import sqlite3
import statistics
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'lib/features/agents/database/agent_repo_core.dart'
DDL = (ROOT / 'lib/features/agents/database/agent_database.drift').read_text().split('CREATE TABLE agent_links')[0]
OLD = '''SELECT id, agent_id, type, subtype, thread_id, created_at,
updated_at, deleted_at, serialized, schema_version FROM (
SELECT agent_entities.*, ROW_NUMBER() OVER (
PARTITION BY agent_id ORDER BY created_at DESC, id DESC) AS rn
FROM agent_entities WHERE agent_id IN ({ids}) AND type = ?
{subtype} AND deleted_at IS NULL) WHERE rn = 1 {predicate}'''


def queries(count, subtype=False, predicate=''):
    body = SOURCE.read_text().split('Future<List<AgentDomainEntity>> latestEntitiesByAgentIds')[1]
    current = body.split("'''", 2)[1]
    subtype_sql = 'AND subtype = ?' if subtype else ''
    current = current.replace('$placeholders', ', '.join(['?'] * count))
    current = current.replace('$subtypePredicate', subtype_sql).replace('$outerPredicate', predicate)
    current = current.replace('$newerSubtypePredicate', 'AND newer.subtype = entity.subtype' if subtype else '')
    old = OLD.format(ids=','.join(['?'] * count), subtype=subtype_sql, predicate=predicate)
    return {'window': old, 'current': current}


def elapsed(conn, sql, args):
    start = time.perf_counter_ns()
    rows = conn.execute(sql, args).fetchall()
    return (time.perf_counter_ns() - start) / 1e6, rows


def compare(path, statements, args):
    conn = sqlite3.connect(path)
    expected = None
    plans, cold, samples, steps = {}, {}, {name: [] for name in statements}, {}
    for name, sql in statements.items():
        plans[name] = [r[3] for r in conn.execute('EXPLAIN QUERY PLAN ' + sql, args)]
        fresh = sqlite3.connect(path)
        cold[name], rows = elapsed(fresh, sql, args)
        fresh.close()
        if expected is None:
            expected = rows
        assert rows == expected, name
        # Count VM instructions in chunks of 100; deterministic work, no timing
        # threshold. Rounded down by at most 99 instructions per execution.
        ticks = [0]
        def tick():
            ticks[0] += 1
            return 0
        conn.set_progress_handler(tick, 100)
        assert conn.execute(sql, args).fetchall() == expected
        conn.set_progress_handler(None, 0)
        steps[name] = ticks[0] * 100
    for turn in range(12):
        order = list(statements)
        if turn % 2:
            order.reverse()
        for name in order:
            ms, rows = elapsed(conn, statements[name], args)
            assert rows == expected
            samples[name].append(ms)
    conn.close()
    return {'rows': len(expected), 'cold_connection_ms': cold,
            'warm_median_ms': {n: statistics.median(v) for n, v in samples.items()},
            'approx_vm_steps': steps, 'plans': plans}


def main():
    results = {'sqlite_version': sqlite3.sqlite_version, 'payload_padding_bytes': 2048,
               'iterations_per_variant': 12, 'cases': []}
    with tempfile.TemporaryDirectory(prefix='lotti-agent-benchmark-') as directory:
        for agent_count, history in ((100, 1), (900, 1), (100, 100), (100, 500)):
            path = pathlib.Path(directory) / f'agents-{agent_count}-{history}.sqlite'
            conn = sqlite3.connect(path)
            conn.executescript(DDL)
            def rows():
                for agent in range(agent_count):
                    for revision in range(history):
                        # Ties, cleared latest predicates and tombstones are
                        # intentional, as are absent requested agents below.
                        payload = json.dumps({'nextWakeAt': '2026-09-06' if revision % 2 else None,
                                              'padding': 'x' * 2048})
                        yield (f'{agent:04}-{revision:04}', f'a{agent:04}', 'agentState', 'state',
                               None, revision // 2, revision, 1 if revision % 11 == 10 else None,
                               payload, 1)
            conn.executemany('INSERT INTO agent_entities VALUES (?,?,?,?,?,?,?,?,?,?)', rows())
            conn.commit()
            conn.close()
            for count in (1, min(agent_count, 897)):
                ids = [f'a{agent:04}' for agent in range(count)] + ['missing']
                for subtype in (False, True):
                    for predicate in ('', "AND json_extract(serialized, '$.nextWakeAt') IS NOT NULL"):
                        args = ids + ['agentState'] + (['state'] if subtype else [])
                        result = compare(path, queries(len(ids), subtype, predicate), args)
                        if count > 1:
                            assert result['approx_vm_steps']['current'] < 0.7 * result['approx_vm_steps']['window'], result
                        results['cases'].append({'history_per_agent': history, 'total_rows': agent_count * history,
                                                 'requested_existing_agents': count, 'subtype': subtype,
                                                 'outer_predicate': bool(predicate), **result})
            # Shape 1: existing ordered limit and unlimited history; shape 2 PK.
            for label, sql, args in (
                ('entity_pk', 'SELECT * FROM agent_entities WHERE id IN (?) AND deleted_at IS NULL', [f'0000-{history-1:04}']),
                ('history_limit_1', 'SELECT * FROM agent_entities WHERE agent_id=? AND type=? AND deleted_at IS NULL ORDER BY created_at DESC LIMIT ?', ['a0000', 'agentState', 1]),
                ('subtype_limit_1', 'SELECT * FROM agent_entities WHERE agent_id=? AND type=? AND subtype=? AND deleted_at IS NULL ORDER BY created_at DESC LIMIT ?', ['a0000', 'agentState', 'state', 1]),
                ('history_unlimited', 'SELECT * FROM agent_entities WHERE agent_id=? AND type=? AND deleted_at IS NULL ORDER BY created_at DESC LIMIT ?', ['a0000', 'agentState', -1]),
            ):
                results['cases'].append({'shape': label, 'history_per_agent': history,
                                         **compare(path, {label: sql}, args)})
        for count in (900, 9000):
            path = pathlib.Path(directory) / f'identities-{count}.sqlite'
            conn = sqlite3.connect(path)
            conn.executescript(DDL)
            conn.executemany('INSERT INTO agent_entities VALUES (?,?,?,?,?,?,?,?,?,?)', (
                (f'identity-{i}', f'agent-{i}', 'agent', None, None, i, i, None,
                 json.dumps({'lifecycle': 'active' if i % 10 == 0 else 'dormant',
                             'padding': 'x' * 2048}), 1) for i in range(count)))
            conn.commit()
            conn.close()
            sql = "SELECT * FROM agent_entities INDEXED BY idx_agent_entities_active_type_created WHERE type=? AND deleted_at IS NULL AND json_extract(serialized, '$.lifecycle')=? ORDER BY created_at DESC"
            results['cases'].append({'shape': 'lifecycle', 'identities': count,
                                     **compare(path, {'current': sql}, ['agent', 'active'])})
    print(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()

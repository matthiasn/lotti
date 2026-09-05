# Habit completion refresh costs

The completion stream used to start one range query per notification, then wait
200 ms *after* fetching. A burst of 100 notifications therefore started 100
queries. The controller now waits before fetching, shares one in-flight read,
and keeps at most one trailing request. Regression tests verify 100 immediate
notifications start one query; 21 overlapping explicit refresh/range requests
start two sequential queries and all wait for the newest range. Notifications
during initial loading are retained, and stale results cannot publish after a
range change or provider invalidation.

The SQL now ranks row IDs before joining winning journal rows to extract their
display fields. This reduces JSON work and window-sort payload without adding an
index or changing the winning-row contract. Local-day partitions, descending
updated/created/end-date/ID tie-breakers, private/deleted filtering, recorded
wall-clock timestamps, and result ordering are preserved. Database tests cover
those timestamp and tie-breaker cases plus source/auto-completion attribution.

## Synthetic experiment

Linux ARM64, Python SQLite 3.45.1, in-memory database, 43,800 synthetic completion
rows: 12 habits over 1,825 days, two revisions per day and approximately 2 KB of
serialized payload. The schema below includes the existing browse index and
config-flag lookup used by this query. Both versions run against the same
connection, alternating six times; the first run is discarded. Results are
asserted identical. These are isolated SQL timings, not end-to-end app latency
or percentiles from the user logs. Other journal tables, disk contention, and
Dart isolate transfer are outside this experiment.

| Range | Winning rows | Before median | After median |
|---|---:|---:|---:|
| 30 days | 360 | 3.46 ms | 2.35 ms |
| 365 days | 4,380 | 63.52 ms | 35.16 ms |
| 1,825 days | 21,900 | 353.47 ms | 182.43 ms |

`EXPLAIN QUERY PLAN` retains the indexed date-range scan and two temporary
sorts. The new join looks up each winner by primary key. The improvement comes
from sorting less data and projecting only winners, not removing those sorts.
The independent controller change also avoids multiplying this cost for every
notification. No machine-dependent timing threshold is imposed on unit tests.

## Reproduce

Run the following Python from the repository root at this change or later.
It obtains the baseline query from commit `ab9427c6d` and the candidate from the
current source. It uses only generated data and creates no database files.

```python
import sqlite3, json, time, statistics, pathlib, datetime, subprocess
query_path='lib/database/database_data_queries.dart'
def query(source):
 return source.split('getHabitCompletionRecordsInRange(')[1].split("r\'\'\'",1)[1].split("\'\'\'",1)[0]
queries={
 'before': query(subprocess.check_output(['git','show','ab9427c6d:'+query_path],text=True)),
 'after': query(pathlib.Path(query_path).read_text()),
}
db=sqlite3.connect(':memory:')
db.executescript('CREATE TABLE journal(id TEXT PRIMARY KEY,type TEXT,private INTEGER,deleted INTEGER,date_from INTEGER,date_to INTEGER,updated_at INTEGER,created_at INTEGER,serialized TEXT); CREATE INDEX idx_journal_browse ON journal(deleted,type,date_from DESC); CREATE TABLE config_flags(name TEXT PRIMARY KEY,status INTEGER); INSERT INTO config_flags VALUES ("private",0);')
start=datetime.datetime(2021,1,1)
def rows():
 for day in range(1825):
  date=start+datetime.timedelta(days=day)
  for habit in range(12):
   for revision in range(2):
    stamp=date+datetime.timedelta(hours=12,seconds=revision)
    epoch=int(stamp.timestamp())
    payload={'meta':{'dateFrom':stamp.isoformat()},'data':{'habitId':f'h{habit}', 'completionType':'success' if revision else 'fail','source':'manual','autoCompleteReason':None},'body':'synthetic journal payload '*80}
    yield (f'{day}-{habit}-{revision}','HabitCompletionEntry',0,0,epoch,epoch,epoch,epoch,json.dumps(payload))
db.executemany('INSERT INTO journal VALUES (?,?,?,?,?,?,?,?,?)',rows());db.commit()
report={'sqlite':sqlite3.sqlite_version,'rows':43800,'habits':12,'historyDays':1825,'revisionsPerDay':2,'measurements':[]}
for days in [30,365,1825]:
 cutoff=int((start+datetime.timedelta(days=1825-days)).timestamp())
 timings={name:[] for name in queries}
 results={}
 for iteration in range(6):
  for name,sql in queries.items():
   t=time.perf_counter();results[name]=db.execute(sql,(cutoff,)).fetchall()
   timings[name].append((time.perf_counter()-t)*1000)
 assert results['before']==results['after']
 assert len(results['after'])==days*12
 assert all(r[2]=='success' for r in results['after'])
 report['measurements'].append({'rangeDays':days,'results':len(results['after']),
  'medianMs':{name:statistics.median(values[1:]) for name,values in timings.items()}})
print(json.dumps(report,indent=2))
```

Storage
=======

**meins** stores your data in a number of so called append logs, one for each day. Using an append log means that new data is only ever added at the end of a file, and nothing overwritten. This is a particularly safe way to safe data as the program cannot accidentally overwrite anything, especially since here we have a single writer, so no two threads and try to append to the log at the same time. Also, an append log easily allows reconstructing previous versions of a journal entry or any other entity. The trade-off here is disk space, is not that much a problem since we're dealing with textual data and a year's worth fits into tens of megabytes.


Location on Disk
----------------

You can find the application's data in the following directories.

Mac: ``~/Library/Application Support/meins``

Windows: ``C:\Users\<you>\AppData\Local\meins``

Linux: ``~/.config/meins``


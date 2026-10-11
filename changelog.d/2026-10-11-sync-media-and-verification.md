### Fixed
- **Two devices verifying each other at the same moment no longer both wait
  forever.** When both sides started the emoji check together, each could
  hold back the other's request for good; the one that should give way now
  does.
- **A photo or recording that arrived cut short is downloaded again** when
  its entry is opened, instead of staying cut off until a manual repair.
- **A missing photo or recording is sent once, not by every device that has
  it.** The device that last sent the entry answers first; the others step
  in only if it doesn't.

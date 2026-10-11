### Fixed
- **Two devices verifying each other at the same moment no longer both wait
  forever.** When both sides started the emoji check together, each could
  hold back the other's request for good; the one that should give way now
  does.
- **A photo or recording that arrived cut short is downloaded again** when
  its entry is opened, instead of staying cut off until a manual repair.

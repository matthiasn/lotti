### Fixed
- **Two devices verifying each other at the same moment no longer both wait
  forever.** When both sides started the emoji check together, each could
  hold back the other's request for good; the one that should give way now
  does.
- **"Show the emoji" reopens the device you were verifying** after your
  device gave way to another's request, and that device is no longer
  offered again without being asked.
- **A photo or recording that arrived cut short is downloaded again** when
  its entry is opened, instead of staying cut off until a manual repair.
- **A missing photo or recording is usually sent by one device, not by every
  device that has it.** The device that last sent the entry answers; the
  others step in after a short wait if it doesn't, or if its copy is
  shorter than theirs.

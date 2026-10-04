### Changed
- **Open pull requests get a checklist item to merge them.** The task agent
  could already suggest checking an item off once an open pull request did
  the work, which left nothing tracking whether that pull request ever
  landed, so a task could be closed while its work sat unmerged. It now also
  suggests a "merge" item for each open pull request linked to the task, and
  suggests checking that item only once GitHub reports the pull request
  merged.

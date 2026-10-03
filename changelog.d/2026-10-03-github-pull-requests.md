### Added
- **Link GitHub pull requests to tasks and follow them there.** Turn on
  *GitHub pull requests* under Settings → Advanced Settings → Config Flags,
  then add your own personal access token under Settings → Advanced
  Settings → GitHub. A task gains a Pull requests card beside its linked
  tasks: paste a pull request's link and it shows whether it is open, merged
  or closed, whether its checks pass, whether it has merge conflicts, how its
  reviews stand, and how long ago GitHub said so. Opening the task refreshes
  anything older than a few minutes, and each pull request has its own
  refresh. Private repositories work, because Lotti reads them through
  GitHub's API with your token — which stays on the device, is never synced,
  and is sent only to api.github.com.

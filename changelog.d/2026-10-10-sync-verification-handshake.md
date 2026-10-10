### Fixed
- **Pairing no longer stalls when both devices open the emoji check at once.**
  Right after a device joined, each side could start the verification at the
  other, and each then sat on a sheet waiting for a request the other never
  showed. One side now hands over to the other's request inside the sheet it
  already has open, and a request that arrives while another verification
  sheet is up is shown as soon as that sheet closes instead of being lost.
- **Closing a verification sheet cancels it for the other device too.** Tapping
  outside the emoji sheet used to leave the other device waiting on a ceremony
  nobody would finish. It now sees the cancellation and can start again.
- **"Show the emoji" reopens the device you were looking at.** When another
  device's keys arrived while a ceremony was open, the button could reopen
  that device instead of the one just dismissed.
- **Add device waits for the device list before showing the pairing code.** A
  code shown while the list was still loading could mistake the device that
  scanned it for one that had been there all along, and never unlock the
  settings and history transfers for it.

### Security
- **Sync rejects attachments that would unpack to an absurd size.** A
  compressed sync attachment is now unpacked only up to a generous limit, far
  above anything Lotti itself sends. One crafted to expand to gigabytes is
  refused, instead of exhausting the device's memory.

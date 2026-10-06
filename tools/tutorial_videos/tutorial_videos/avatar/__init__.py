"""The talking avatar: a small cartoon character in a round badge that lip-syncs
the tutorial narration from the corner of the video.

Everything here is stdlib-only (like the rest of the workbench, ``publish``'s
boto3 aside): the character is drawn from flat shapes by ``raster.py``, its
mouth follows the narration's loudness (``lipsync.py``), and ffmpeg turns the
handful of distinct poses into a clip (``render.py``).
"""


class AvatarError(Exception):
    """An avatar input or render step failed."""

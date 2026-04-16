const configNotFound = 'Could not find Matrix Config';
const syncMessageType = 'com.lotti.sync.message';
const String matrixConfigKey = 'MATRIX_CONFIG';
const String matrixRoomKey = 'MATRIX_ROOM';
const String lastReadMatrixEventId = 'LAST_READ_MATRIX_EVENT_ID';
const String lastReadMatrixEventTs = 'LAST_READ_MATRIX_EVENT_TS';

const String syncLoggingDomain = 'MATRIX_SYNC';

/// Key in a sync attachment event's content that declares an on-wire encoding
/// applied by the sender. Absent means the bytes are the payload verbatim.
const String attachmentEncodingKey = 'com.lotti.encoding';

/// Value for [attachmentEncodingKey] indicating the attachment bytes are
/// gzip-compressed; the receiver must decompress before writing to disk.
const String attachmentEncodingGzip = 'gzip';

/// Key in an attachment event's content that marks the file as a zip
/// containing multiple inner attachments. Entries inside the zip are named
/// after their target relative paths. Receivers that understand this marker
/// unpack the zip and write each entry to its inner path instead of writing
/// the zip itself. Receivers that do not understand the marker will still
/// write the zip to the outer `relativePath`, which is harmless because that
/// path is under `.bundles/` and is not referenced by any sync payload.
const String attachmentBundleKey = 'com.lotti.bundle';

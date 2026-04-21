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

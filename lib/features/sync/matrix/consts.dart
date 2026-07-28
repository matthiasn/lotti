const configNotFound = 'Could not find Matrix Config';
const syncMessageType = 'com.lotti.sync.message';
const String matrixConfigKey = 'MATRIX_CONFIG';
const String matrixRoomKey = 'MATRIX_ROOM';
const String lastReadMatrixEventId = 'LAST_READ_MATRIX_EVENT_ID';
const String lastReadMatrixEventTs = 'LAST_READ_MATRIX_EVENT_TS';

const String syncLoggingDomain = 'MATRIX_SYNC';

/// Room state event type stamped on a room to mark it as a Lotti sync room.
///
/// Rooms are created out of band and reach a device through the provisioning
/// bundle, so nothing writes this marker any more; the actor's outbound queue
/// still reads it to pick the sync room out of the joined rooms.
const String lottiSyncRoomStateType = 'm.lotti.sync_room';

/// Key in a sync attachment event's content that declares an on-wire encoding
/// applied by the sender. Absent means the bytes are the payload verbatim.
const String attachmentEncodingKey = 'com.lotti.encoding';

/// Value for [attachmentEncodingKey] indicating the attachment bytes are
/// gzip-compressed; the receiver must decompress before writing to disk.
const String attachmentEncodingGzip = 'gzip';

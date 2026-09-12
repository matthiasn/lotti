import 'package:glados/glados.dart';
import 'package:lotti/features/system_health/service/log_redactor.dart';

void main() {
  const redactor = LogRedactor();

  test('replaces email addresses', () {
    expect(
      redactor.redact('user matthias.nehlsen+test@example.co.uk retried'),
      'user [email] retried',
    );
  });

  test('keeps the first six characters of a UUID for correlation', () {
    expect(
      redactor.redact('host=19d6f0b3-7d45-4ca1-aeb2-8829cac4b42e count=12'),
      'host=[id:19d6f0] count=12',
    );
  });

  test('replaces Matrix user, room and event ids', () {
    expect(
      redactor.redact(
        r'from @alice:matrix.org in !abc123:matrix.org event $ev1:matrix.org',
      ),
      'from [matrix-id] in [matrix-id] event [matrix-id]',
    );
  });

  test('replaces credential values but keeps the key name', () {
    expect(
      redactor.redact('api_key=sk-live-1234 token: "abc" password=hunter2'),
      'api_key=[redacted] token: [redacted] password=[redacted]',
    );
    expect(
      redactor.redact('Authorization: Bearer eyJhbGciOi.payload.sig'),
      'Authorization: [redacted]',
    );
  });

  test('replaces long opaque tokens but not code paths', () {
    final secret = 'a1B2c3D4' * 6;
    expect(redactor.redact('key $secret end'), 'key [token] end');
    expect(
      redactor.redact(
        'GoalAgentWorkflow.execute '
        '(package:lotti/features/goals/workflow/goal_agent_workflow.dart:707:9)',
      ),
      'GoalAgentWorkflow.execute '
      '(package:lotti/features/goals/workflow/goal_agent_workflow.dart:707:9)',
    );
  });

  test('hides the username in home-directory paths', () {
    expect(
      redactor.redact(r'/Users/matthias/Library/x /home/mn/y C:\Users\Bob\z'),
      r'/Users/[user]/Library/x /home/[user]/y C:\Users\[user]\z',
    );
  });

  test('replaces IPv4 addresses and international phone numbers', () {
    expect(
      redactor.redact('peer 192.168.1.20 called +49 170 1234567 twice'),
      'peer [ip] called [phone] twice',
    );
  });

  test('leaves counters, durations and timestamps alone', () {
    const line =
        'wake completed in 20900ms started=2026-09-12T01:32:41.334188 '
        'counters=[2394, 3610, 3903]';
    expect(redactor.redact(line), line);
  });

  test('strips URL query strings and user info but keeps the host', () {
    expect(
      redactor.redact('GET https://bob:pw@api.example.com/v1/x?key=abc&y=1 ok'),
      'GET https://[credentials]@api.example.com/v1/x?[query] ok',
    );
  });

  test('empty input is returned as is', () {
    expect(redactor.redact(''), '');
  });

  Glados<String>(any.letterOrDigits).test(
    'no email survives redaction wherever it is embedded',
    (word) {
      final text = 'a x$word@example.org b $word <x$word.x@mail.test>';
      final redacted = redactor.redact(text);
      expect(redacted, isNot(contains('@example.org')));
      expect(redacted, isNot(contains('@mail.test')));
    },
    tags: 'glados',
  );

  Glados<String>(any.letterOrDigits).test(
    'redaction is idempotent',
    (word) {
      final text = 'host=19d6f0b3-7d45-4ca1-aeb2-8829cac4b42e $word user@x.io';
      final once = redactor.redact(text);
      expect(redactor.redact(once), once);
    },
    tags: 'glados',
  );
}

import assert from 'node:assert/strict';
import test from 'node:test';

import {tutorialVideoSource} from '../src/components/TutorialVideo/videoSource.mjs';

test('tutorial video URLs combine the base, scenario, and locale', () => {
  assert.equal(
    tutorialVideoSource({
      scenario: 'create_task_from_audio',
      locale: 'de',
      videoBaseUrl: 'https://media.example/tutorial-videos/',
    }),
    'https://media.example/tutorial-videos/create_task_from_audio_de.mp4',
  );
});

test('a trailing slash on the base URL is not duplicated', () => {
  assert.equal(
    tutorialVideoSource({
      scenario: 'task_filters',
      locale: 'en',
      videoBaseUrl: 'https://media.example/tutorial-videos',
    }),
    'https://media.example/tutorial-videos/task_filters_en.mp4',
  );
});

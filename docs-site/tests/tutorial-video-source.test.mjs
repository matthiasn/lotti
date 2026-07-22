import assert from 'node:assert/strict';
import test from 'node:test';

import {
  tutorialCaptionsSource,
  tutorialVideoSource,
} from '../src/components/TutorialVideo/videoSource.mjs';

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

test('a base URL without a trailing slash still gets exactly one separator', () => {
  assert.equal(
    tutorialVideoSource({
      scenario: 'task_filters',
      locale: 'en',
      videoBaseUrl: 'https://media.example/tutorial-videos',
    }),
    'https://media.example/tutorial-videos/task_filters_en.mp4',
  );
});

test('a trailing slash on the base URL is not duplicated', () => {
  assert.equal(
    tutorialVideoSource({
      scenario: 'task_filters',
      locale: 'en',
      videoBaseUrl: 'https://media.example/tutorial-videos/',
    }),
    'https://media.example/tutorial-videos/task_filters_en.mp4',
  );
});

test('caption URLs match the video URL with a .vtt extension', () => {
  assert.equal(
    tutorialCaptionsSource({
      scenario: 'create_task_from_audio',
      locale: 'de',
      videoBaseUrl: 'https://media.example/tutorial-videos/',
    }),
    'https://media.example/tutorial-videos/create_task_from_audio_de.vtt',
  );
});

test('the desktop viewport keeps the unsuffixed, backward-compatible URL', () => {
  assert.equal(
    tutorialVideoSource({
      scenario: 'create_task_from_audio',
      locale: 'de',
      videoBaseUrl: 'https://media.example/tutorial-videos/',
      viewport: 'desktop',
    }),
    'https://media.example/tutorial-videos/create_task_from_audio_de.mp4',
  );
});

test('the mobile viewport gets a _mobile suffix on both video and captions', () => {
  assert.equal(
    tutorialVideoSource({
      scenario: 'create_task_from_audio',
      locale: 'de',
      videoBaseUrl: 'https://media.example/tutorial-videos/',
      viewport: 'mobile',
    }),
    'https://media.example/tutorial-videos/create_task_from_audio_de_mobile.mp4',
  );
  assert.equal(
    tutorialCaptionsSource({
      scenario: 'create_task_from_audio',
      locale: 'de',
      videoBaseUrl: 'https://media.example/tutorial-videos/',
      viewport: 'mobile',
    }),
    'https://media.example/tutorial-videos/create_task_from_audio_de_mobile.vtt',
  );
});

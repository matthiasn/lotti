import { Machine } from 'xstate'
import AudioRecorderPlayer from 'react-native-audio-recorder-player'

export interface AudioRecorderStateSchema {
  states: {
    recording: {}
    playing: {}
    paused: {}
    stopped: {}
  }
}

export interface AudioRecorderContext {
  currentPositionSec?: number;
  currentDurationSec?: number;
  playTime?: string;
  duration?: string;
  recordTime?: string;
  recordSecs?: number;
}
const audioRecorderPlayer = new AudioRecorderPlayer();

export const audioRecorderMachine = Machine<
  AudioRecorderContext,
  AudioRecorderStateSchema
  >({
  initial: 'stopped',
  context: {
  },
  states: {
    stopped: {},
    recording: {},
    playing: {},
    paused: {},
  },
})

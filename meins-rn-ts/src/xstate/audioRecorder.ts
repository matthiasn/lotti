import { Machine } from 'xstate'
import { ImmerUpdateEvent } from '@xstate/immer'
import { enableAllPlugins } from 'immer'

enableAllPlugins()

export interface AudioRecorderStateSchema {
  states: {
    recording: Record<string, unknown>
    playing: Record<string, unknown>
    paused: Record<string, unknown>
    stopped: Record<string, unknown>
  }
}

export interface AudioRecorderContext {
  currentPositionSec?: number
  currentDurationSec?: number
  playTime?: string
  duration?: string
  recordTime?: string
  recordSecs?: number
}

export type RecordEvent = ImmerUpdateEvent<'RECORD'>
export type PlayEvent = ImmerUpdateEvent<'PLAY'>
export type StopEvent = ImmerUpdateEvent<'STOP'>
export type PauseEvent = ImmerUpdateEvent<'PAUSE'>

export type AudioRecorderEvent = RecordEvent | PlayEvent | StopEvent | PauseEvent

export const audioRecorderMachine = Machine<
  AudioRecorderContext,
  AudioRecorderStateSchema,
  AudioRecorderEvent
>({
  initial: 'stopped',
  context: {},
  states: {
    stopped: {
      on: {
        PLAY: {
          target: 'playing',
        },
        RECORD: {
          target: 'recording',
        },
      },
    },
    recording: {
      on: {
        STOP: {
          target: 'stopped',
        },
      },
    },
    playing: {
      on: {
        STOP: {
          target: 'stopped',
        },
      },
    },
    paused: {
      on: {
        PLAY: {
          target: 'playing',
        },
      },
    },
  },
})

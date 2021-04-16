import { Machine } from 'xstate'
import { assign } from '@xstate/immer'
import { enableAllPlugins } from 'immer'

enableAllPlugins()

export interface AudioRecorderStateSchema {
  states: {
    empty: Record<string, unknown>
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

export type RecordEvent = { type: 'RECORD' }
export type RecordProgressEvent = {
  type: 'RECORD_PROGRESS'
  recordSecs: number
  recordTime: string
}

export type PlayEvent = { type: 'PLAY' }
export type PlayProgressEvent = {
  type: 'PLAY_PROGRESS'
  currentPositionSec: number
  currentDurationSec: number
  playTime: string
  duration: string
}

export type StopEvent = { type: 'STOP' }
export type PauseEvent = { type: 'PAUSE' }

export type AudioRecorderEvent =
  | RecordEvent
  | PlayEvent
  | StopEvent
  | PauseEvent
  | RecordProgressEvent
  | PlayProgressEvent

export const audioRecorderMachine = Machine<
  AudioRecorderContext,
  AudioRecorderStateSchema,
  AudioRecorderEvent
>({
  initial: 'empty',
  context: {},
  states: {
    empty: {
      on: {
        RECORD: {
          target: 'recording',
        },
      },
    },
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
        RECORD_PROGRESS: {
          actions: assign<AudioRecorderContext, RecordProgressEvent>(
            (context, { recordSecs, recordTime }) => {
              context.recordSecs = recordSecs
              context.recordTime = recordTime
            },
          ),
        },
      },
    },
    playing: {
      on: {
        STOP: {
          target: 'stopped',
        },
        PAUSE: {
          target: 'paused',
        },
        PLAY_PROGRESS: {
          actions: assign<AudioRecorderContext, PlayProgressEvent>(
            (context, { currentPositionSec, currentDurationSec, playTime, duration }) => {
              context.currentPositionSec = currentPositionSec
              context.currentDurationSec = currentDurationSec
              context.playTime = playTime
              context.duration = duration
            },
          ),
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

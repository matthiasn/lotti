import { interpret, Machine } from 'xstate'
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
export type PlayEvent = { type: 'PLAY' }
export type StopEvent = { type: 'STOP' }
export type PauseEvent = { type: 'PAUSE' }

export type AudioRecorderEvent = RecordEvent | PlayEvent | StopEvent | PauseEvent

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
          actions: assign<AudioRecorderContext, RecordEvent>((_context) => {
            console.log('RECORD')
          }),
        },
      },
    },
    stopped: {
      on: {
        PLAY: {
          target: 'playing',
          actions: assign<AudioRecorderContext, PlayEvent>((_context) => {}),
        },
        RECORD: {
          target: 'recording',
          actions: assign<AudioRecorderContext, RecordEvent>((_context) => {}),
        },
      },
    },
    recording: {
      on: {
        STOP: {
          target: 'stopped',
          actions: assign<AudioRecorderContext, StopEvent>((_context) => {}),
        },
      },
    },
    playing: {
      on: {
        STOP: {
          target: 'stopped',
          actions: assign<AudioRecorderContext, StopEvent>((_context) => {}),
        },
        PAUSE: {
          target: 'paused',
          actions: assign<AudioRecorderContext, PauseEvent>((_context) => {}),
        },
      },
    },
    paused: {
      on: {
        PLAY: {
          target: 'playing',
          actions: assign<AudioRecorderContext, PlayEvent>((_context) => {}),
        },
      },
    },
  },
})

export const audioRecorderService = interpret(audioRecorderMachine, {})
  .onTransition((state) => {
    console.log(state.context)
  })
  .start()

import { interpret, Machine } from 'xstate'
import { assign } from '@xstate/immer'
import { enableAllPlugins } from 'immer'
import { Entry } from 'src/db/realmPersistence'

enableAllPlugins()

export interface EntriesMachineStateSchema {
  states: {
    idle: Record<string, unknown>
    playing: Record<string, unknown>
    paused: Record<string, unknown>
    stopped: Record<string, unknown>
  }
}

export interface EntriesMachineContext {
  currentPositionSec?: number
  durationSec?: number
  playTime?: string
  duration?: string
  recordTime?: string
  recordSecs?: number
  currentEntry?: Entry
  entries: Entry[]
}

export type PlayEvent = { type: 'PLAY' }
export type PlayProgressEvent = {
  type: 'PLAY_PROGRESS'
  currentPositionSec: number
  durationSec: number
  playTime: string
  duration: string
}

export type StopEvent = { type: 'STOP' }
export type PauseEvent = { type: 'PAUSE' }

export type EntriesMachineEvent = PlayEvent | StopEvent | PauseEvent | PlayProgressEvent

export const playbackMachine = Machine<
  EntriesMachineContext,
  EntriesMachineStateSchema,
  EntriesMachineEvent
>({
  initial: 'idle',
  context: {
    entries: [],
  },
  states: {
    idle: {},
    stopped: {
      on: {
        PLAY: {
          target: 'playing',
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
          actions: assign<EntriesMachineContext, PlayProgressEvent>(
            (context, { currentPositionSec, durationSec, playTime, duration }) => {
              context.currentPositionSec = currentPositionSec
              context.durationSec = durationSec
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

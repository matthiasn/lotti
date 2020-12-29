import { NavScreen, stateVar } from '../../gql/client'
import { TabSides } from '../../modules/tab-view'

export function setTabQuery(side: TabSides, query: string) {
  const state = stateVar()
  if (side === TabSides.left) {
    stateVar({ ...state, left: query })
  } else {
    stateVar({ ...state, right: query })
  }
}

export function toggleSettings() {
  const state = stateVar()
  const screen =
    state.screen === NavScreen.HOME ? NavScreen.SETTINGS : NavScreen.HOME
  stateVar({ ...state, screen })
}

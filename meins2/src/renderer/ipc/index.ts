import { ipcRenderer } from 'electron'
import { toggleSettings } from '../helpers/nav'

ipcRenderer.on('menu', (event, message) => {
  console.log('IPC received:', message)

  if (message === 'toggle-preferences') {
    toggleSettings()
  }
})

import { BrowserWindow } from 'electron'

let mainWindowRef: BrowserWindow

export function setMainWindow(window: BrowserWindow) {
  mainWindowRef = window
}

export function sendToMainWindow(channel: string, args: string) {
  if (mainWindowRef) {
    mainWindowRef.webContents.send(channel, args)
  }
}

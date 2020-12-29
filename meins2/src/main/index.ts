import { app, BrowserWindow, shell } from 'electron'
import contextMenu from 'electron-context-menu'
import './menu'
import { setMainWindow } from './ipc'

declare const MAIN_WINDOW_WEBPACK_ENTRY: any

// Handle creating/removing shortcuts on Windows when installing/uninstalling.
if (require('electron-squirrel-startup')) {
  // eslint-disable-line global-require
  app.quit()
}

contextMenu({
  prepend: (defaultActions, params, browserWindow) => [
    {
      label: 'Rainbow',
      // Only show it when right-clicking images
      visible: params.mediaType === 'image',
    },
    {
      label: 'Search Google for “{selection}”',
      // Only show it when right-clicking text
      visible: params.selectionText.trim().length > 0,
      click: () => {
        shell.openExternal(
          `https://google.com/search?q=${encodeURIComponent(
            params.selectionText,
          )}`,
        )
      },
    },
  ],
})

const createWindow = (): void => {
  const mainWindow = new BrowserWindow({
    height: 768,
    width: 1024,
    titleBarStyle: 'hidden',
    webPreferences: {
      nodeIntegration: true,
    },
  })

  setMainWindow(mainWindow)

  // and load the index.html of the app.
  mainWindow.loadURL(MAIN_WINDOW_WEBPACK_ENTRY)

  // Open the DevTools.
  mainWindow.webContents.openDevTools()
}

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.on('ready', createWindow)

// Quit when all windows are closed, except on macOS. There, it's common
// for applications and their menu bar to stay active until the user quits
// explicitly with Cmd + Q.
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
  }
})

app.on('activate', () => {
  // On OS X it's common to re-create a window in the app when the
  // dock icon is clicked and there are no other windows open.
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow()
  }
})

import { app, Menu, MenuItemConstructorOptions } from 'electron'
import { sendToMainWindow } from './ipc'

const isMac = process.platform === 'darwin'

const template = [
  ...(isMac
    ? [
        {
          label: app.name,
          submenu: [
            { role: 'about' },
            { type: 'separator' },
            { label: 'Check for Updates' },
            {
              label: 'Preferences',
              accelerator: 'Cmd+,',
              click: () => sendToMainWindow('menu', 'toggle-preferences'),
            },
            { type: 'separator' },
            { label: 'Start Spotify Service' },
            { role: 'unhide' },
            { type: 'separator' },
            {
              label: 'Quit Background Service',
            },
            { role: 'quit' },
          ],
        },
      ]
    : []),
  // { role: 'fileMenu' }
  {
    label: 'File',
    submenu: [
      { label: 'New Entry', accelerator: 'CmdOrCtrl+N' },
      {
        label: 'New...',
        submenu: [
          { label: 'Task', accelerator: 'CmdOrCtrl+T' },
          { label: 'Story' },
          { label: 'Saga' },
          { label: 'Problem' },
          { label: 'Habit' },
          { label: 'Album' },
          { label: 'Dashboard' },
          { label: 'Custom Field' },
        ],
      },
      {
        label: 'Import...',
        submenu: [
          { label: 'Photos', accelerator: 'CmdOrCtrl+I' },
          { label: 'Git repos' },
          { label: 'Spotify Most Listened' },
        ],
      },
      { label: 'Export...', submenu: [{ label: 'GeoJSON' }] },
      isMac ? { role: 'close' } : { role: 'quit' },
    ],
  },
  // { role: 'editMenu' }
  {
    label: 'Edit',
    submenu: [
      { role: 'undo' },
      { role: 'redo' },
      { type: 'separator' },
      { role: 'cut' },
      { role: 'copy' },
      { role: 'paste' },
      ...(isMac
        ? [
            { role: 'pasteAndMatchStyle' },
            { role: 'delete' },
            { role: 'selectAll' },
            { type: 'separator' },
            {
              label: 'Speech',
              submenu: [{ role: 'startSpeaking' }, { role: 'stopSpeaking' }],
            },
          ]
        : [{ role: 'delete' }, { type: 'separator' }, { role: 'selectAll' }]),
      {
        label: 'Spelling',
        submenu: [
          { label: 'English' },
          { label: 'French' },
          { label: 'German' },
          { label: 'Italian' },
          { label: 'Spanish' },
          { type: 'separator' },
          { label: 'OFF' },
        ],
      },
    ],
  },
  // { role: 'viewMenu' }
  {
    label: 'View',
    submenu: [
      { role: 'reload' },
      { role: 'forceReload' },
      { role: 'toggleDevTools' },
      { type: 'separator' },
      { role: 'resetZoom' },
      { role: 'zoomIn' },
      { role: 'zoomOut' },
      { type: 'separator' },
      { role: 'togglefullscreen' },
    ],
  },
  // { role: 'windowMenu' }
  {
    label: 'Window',
    submenu: [
      { role: 'minimize' },
      { role: 'zoom' },
      ...(isMac
        ? [
            { type: 'separator' },
            { role: 'front' },
            { type: 'separator' },
            { role: 'window' },
          ]
        : [{ role: 'close' }]),
    ],
  },
  {
    role: 'help',
    submenu: [
      {
        label: 'Learn More',
        click: async () => {
          const { shell } = require('electron')
          await shell.openExternal('https://github.com/matthiasn/meins')
        },
      },
    ],
  },
] as MenuItemConstructorOptions[]

const menu = Menu.buildFromTemplate(template)
Menu.setApplicationMenu(menu)

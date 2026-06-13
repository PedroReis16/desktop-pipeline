const { app, BrowserWindow, shell } = require('electron');
const path = require('node:path');

// Em modo de desenvolvimento carregamos o dev-server do Angular.
// Em produção (app empacotado ou build local) carregamos os arquivos estáticos.
const isDev = !app.isPackaged && process.env.NODE_ENV === 'development';
const DEV_SERVER_URL = process.env.ELECTRON_DEV_SERVER_URL || 'http://localhost:4200';
const INDEX_HTML = path.join(__dirname, '..', 'dist', 'desktop-ui', 'browser', 'index.html');

/** @type {BrowserWindow | null} */
let mainWindow = null;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 800,
    minHeight: 600,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  mainWindow.once('ready-to-show', () => mainWindow?.show());

  // Abre links externos no navegador padrão em vez de dentro do app.
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });

  if (isDev) {
    mainWindow.loadURL(DEV_SERVER_URL);
    mainWindow.webContents.openDevTools({ mode: 'detach' });
  } else {
    mainWindow.loadFile(INDEX_HTML);
  }

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

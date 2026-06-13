const { contextBridge } = require('electron');

// Ponte segura entre o processo de renderização (Angular) e o Electron.
// Adicione aqui apenas APIs explicitamente necessárias, mantendo contextIsolation.
contextBridge.exposeInMainWorld('electronAPI', {
  platform: process.platform,
  versions: {
    electron: process.versions.electron,
    chrome: process.versions.chrome,
    node: process.versions.node,
  },
});

import { ApplicationConfig, provideBrowserGlobalErrorListeners } from '@angular/core';
import { provideRouter, withHashLocation } from '@angular/router';

import { routes } from './app.routes';

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    // Hash routing garante que a navegação funcione sob o protocolo file://
    // usado pelo Electron no app empacotado.
    provideRouter(routes, withHashLocation())
  ]
};

import { WebPlugin } from '@capacitor/core';

export class CapacitorVideoRecorderWeb extends WebPlugin {
  constructor() {
    super({
      name: 'CapacitorVideoRecorder',
      platforms: ['web']
    });
  }

}

const MyPlugin = new CapacitorVideoRecorderWeb();

export { MyPlugin };

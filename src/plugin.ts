import { Plugins } from '@capacitor/core';
import {
  ICapacitorVideoRecorder,
  CapacitorVideoRecorderOptions,
  CapacitorVideoRecorderQuality,
  CapacitorVideoRecorderPosition
} from './definitions';

const { CapacitorVideoRecorderPlugin } = Plugins;

export class CapacitorVideoRecorder implements ICapacitorVideoRecorder {
  constructor() {}

  initialize(): Promise<any> {
    return CapacitorVideoRecorderPlugin.initialize();
  }
  destroy(): Promise<any> {
    return CapacitorVideoRecorderPlugin.destroy();
  }
  show(options: CapacitorVideoRecorderOptions): Promise<any> {
    const opts = options || {};
    Object.assign(opts, {
      quality: options.quality
        ? options.quality
        : CapacitorVideoRecorderQuality.MAX_480P,
      position: options.position
        ? options.position
        : CapacitorVideoRecorderPosition.BACK
    });
    return CapacitorVideoRecorderPlugin.show(options);
  }
  hide(): Promise<any> {
    return CapacitorVideoRecorderPlugin.hide();
  }
  togglePip(): Promise<{ pictureInPicture: boolean }> {
    return CapacitorVideoRecorderPlugin.togglePip();
  }
  startRecording(): Promise<any> {
    return CapacitorVideoRecorderPlugin.startRecording();
  }
  stopRecording(): Promise<{ videoUrl: string }> {
    return CapacitorVideoRecorderPlugin.stopRecording();
  }
  getDuration(): Promise<{ value: number }> {
    return CapacitorVideoRecorderPlugin.getDuration();
  }
  toggleCamera(): Promise<any> {
    return CapacitorVideoRecorderPlugin.toggleCamera();
  }
}

declare global {
  interface PluginRegistry {
    CapacitorVideoRecorderPlugin?: ICapacitorVideoRecorder;
  }
}

export interface ICapacitorVideoRecorder {
  initialize(): Promise<any>;
  destroy(): Promise<any>;
  toggleCamera(): Promise<any>;
  show(options: CapacitorVideoRecorderOptions): Promise<any>;
  hide(): Promise<any>;
  togglePip(): Promise<{ pictureInPicture: boolean }>;
  startRecording(): Promise<any>;
  stopRecording(): Promise<{ videoUrl: string }>;
  getDuration(): Promise<{ value: number }>;
}

export interface CapacitorVideoRecorderOptions {
  position?: CapacitorVideoRecorderPosition;
  quality?: CapacitorVideoRecorderQuality;
}

export enum CapacitorVideoRecorderPosition {
  FRONT,
  BACK
}

export enum CapacitorVideoRecorderQuality {
  MAX_480P,
  MAX_720P,
  MAX_1080P,
  MAX_2160P,
  HIGHEST,
  LOWEST,
  QVGA
}

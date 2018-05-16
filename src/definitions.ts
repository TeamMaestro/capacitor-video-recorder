declare global {
	interface PluginRegistry {
		CapacitorVideoRecorderPlugin?: ICapacitorVideoRecorder;
	}
}

export interface ICapacitorVideoRecorder {
	initialize(): Promise<any>;
	destroy(): Promise<any>;
	show(): Promise<any>;
	hide(): Promise<any>;
	togglePip(): Promise<{pictureInPicture: boolean}>;
	startRecording(): Promise<any>;
	stopRecording(): Promise<{videoUrl: string}>;
}

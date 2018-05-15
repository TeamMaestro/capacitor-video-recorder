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
	toggle(): Promise<any>;
	startRecording(): Promise<any>;
	stopRecording(): Promise<any>;
	getStatus(): Promise<any[]>;
}

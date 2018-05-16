import { Plugins } from '@capacitor/core';
import { ICapacitorVideoRecorder } from './definitions';

const { CapacitorVideoRecorderPlugin } = Plugins;

export class CapacitorVideoRecorder implements ICapacitorVideoRecorder {

	constructor() { }

	initialize(): Promise<any> {
		return CapacitorVideoRecorderPlugin.initialize();
	}
	destroy(): Promise<any> {
		return CapacitorVideoRecorderPlugin.destroy();
	}
	show(): Promise<any> {
		return CapacitorVideoRecorderPlugin.show();
	}
	hide(): Promise<any> {
		return CapacitorVideoRecorderPlugin.hide();
	}
	togglePip(): Promise<{pictureInPicture: boolean}> {
		return CapacitorVideoRecorderPlugin.togglePip();
	}
	startRecording(): Promise<any> {
		return CapacitorVideoRecorderPlugin.startRecording();
	}
	stopRecording(): Promise<{videoUrl: string}> {
		return CapacitorVideoRecorderPlugin.stopRecording();
	}

}
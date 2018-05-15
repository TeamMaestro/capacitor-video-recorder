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
	toggle(): Promise<any> {
		return CapacitorVideoRecorderPlugin.toggle();
	}
	startRecording(): Promise<any> {
		return CapacitorVideoRecorderPlugin.startRecording();
	}
	stopRecording(): Promise<any> {
		return CapacitorVideoRecorderPlugin.stopRecording();
	}
	getStatus(): Promise<any[]> {
		return CapacitorVideoRecorderPlugin.getStatus();
	}

}
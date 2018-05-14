import { Plugins } from '@capacitor/core';
import { ICapacitorVideoRecorder } from './definitions';

const { CapacitorVideoRecorderPlugin } = Plugins;

export class CapacitorVideoRecorder implements ICapacitorVideoRecorder {

	constructor() { }

	echo(options: {value: string}): Promise<{ value: string }> {
		return CapacitorVideoRecorderPlugin.echo(options);
	}
}
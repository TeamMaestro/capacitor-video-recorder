declare global {
	interface PluginRegistry {
		CapacitorVideoRecorderPlugin?: ICapacitorVideoRecorder;
	}
}

export interface ICapacitorVideoRecorder {
	echo(options: { value: string }): Promise<{ value: string }>;
}

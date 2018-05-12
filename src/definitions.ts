declare global {
	interface PluginRegistry {
		CapacitorVideoRecorder?: CapacitorVideoRecorderPlugin;
	}
}

export interface CapacitorVideoRecorderPlugin {
	echo(options: { value: string }): Promise<{ value: string }>;
}

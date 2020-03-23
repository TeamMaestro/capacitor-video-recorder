import { WebPlugin, registerWebPlugin } from '@capacitor/core';
import { VideoRecorderPlugin, VideoRecorderOptions, VideoRecorderPreviewFrame } from './definitions';

class DropShadow {
	opacity?: number;
	radius?: number;
	color?: string;

	constructor(options: DropShadow = <DropShadow>{}) {
		this.opacity = options.opacity || 0;
		this.radius = options.radius || 0;
		this.color = hexToRgb(options.color || '#000000');

		function hexToRgb(hex: string): string {
			let shorthandRegex = /^#?([a-f\d])([a-f\d])([a-f\d])$/i;
			hex = hex.replace(shorthandRegex, function(_m, r, g, b) {
				return r + r + g + g + b + b;
			});
			let result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
			return result ? `${parseInt(result[1], 16)}, ${parseInt(result[2], 16)}, ${parseInt(result[3], 16)}` : null;
		}
	}
}

class FrameConfig {
	id: string;
	stackPosition?: 'front' | 'back';
	x?: number;
	y?: number;
	width?: number | 'fill';
	height?: number | 'fill';
	borderRadius?: number;
	dropShadow?: DropShadow;

	constructor(options: FrameConfig = <FrameConfig>{}) {
		this.id = options.id;
		this.stackPosition = options.stackPosition || 'back';
		this.x = options.x || 0;
		this.y = options.y || 0;
		this.width = options.width || 'fill';
		this.height = options.height || 'fill';
		this.borderRadius = options.borderRadius || 0;
		this.dropShadow = new DropShadow(options.dropShadow)
	}
}

export class VideoRecorderWeb extends WebPlugin implements VideoRecorderPlugin {

	videoElement: HTMLVideoElement;
	stream: MediaStream;

	previewFrameConfigs: FrameConfig[] = [];
	currentFrameConfig: FrameConfig = new FrameConfig({id: 'default'});

	constructor() {
		super({
			name: 'VideoRecorder',
			platforms: ['web']
		});
	}

	private _initializeCameraView() {
		this.videoElement = document.createElement('video');
		this.videoElement.autoplay = true;
		this.videoElement.hidden = true;
		this.videoElement.style.cssText = `
			object-fit: cover;
			pointer-events: none;
			position: absolute;
		`;
		document.body.appendChild(this.videoElement);

		this._updateCameraView(this.currentFrameConfig);
	}

	private _updateCameraView(config: FrameConfig) {
		this.videoElement.style.width = config.width === 'fill' ? '100vw' : `${config.width}px`;
		this.videoElement.style.height = config.height === 'fill' ? '100vh' : `${config.height}px`;
		this.videoElement.style.left = `${config.x}px`;
		this.videoElement.style.top = `${config.y}px`;
		this.videoElement.style.zIndex = config.stackPosition === 'back' ? '-1' : '99999';
		this.videoElement.style.borderRadius = `${config.borderRadius}px`;
		this.videoElement.style.boxShadow = `0 0 ${config.dropShadow.radius}px 0 rgba(${config.dropShadow.color}, ${config.dropShadow.opacity})`;
	}

	async initialize(options?: VideoRecorderOptions): Promise<void> {
		console.warn('VideoRecorder: Web implementation is currently for mock purposes only, recording is not available');
		let previewFrames = options.previewFrames.length > 0 ? options.previewFrames : [{id: 'default'}];
		this.previewFrameConfigs = previewFrames.map(config => new FrameConfig(config));
		this.currentFrameConfig = this.previewFrameConfigs[0];
		
		this._initializeCameraView();

		if (options.autoShow !== false) {
			this.videoElement.hidden = false;
		}

		if (navigator.mediaDevices.getUserMedia) {       
			this.stream = await navigator.mediaDevices.getUserMedia({video: true})
			this.videoElement.srcObject = this.stream;
		}
    	return Promise.resolve();
	}
	destroy(): Promise<any> {
		this.videoElement.remove();
		this.previewFrameConfigs = [];
		this.currentFrameConfig = undefined;
		this.stream.getTracks().forEach(track => track.stop());
    	return Promise.resolve();
	}
	flipCamera(): Promise<void> {
		console.warn('VideoRecorder: No web mock available for flipCamera');
		return Promise.resolve();
	}
	addPreviewFrameConfig(config: VideoRecorderPreviewFrame): Promise<void> {
		if (this.videoElement) {
			if (!config.id) {
				return Promise.reject('id required');
			}
			let newFrame = new FrameConfig(config);
			if (this.previewFrameConfigs.map(config => config.id).indexOf(newFrame.id) === -1) {
				this.previewFrameConfigs.push(newFrame);
			}
			else {
				this.editPreviewFrameConfig(config);
			}
		}
		return Promise.resolve();
	}
	editPreviewFrameConfig(config: VideoRecorderPreviewFrame): Promise<void> {
		if (this.videoElement) {
			if (!config.id) {
				return Promise.reject('id required');
			}
			let updatedFrame = new FrameConfig(config);
			let existingIndex = this.previewFrameConfigs.map(config => config.id).indexOf(updatedFrame.id)
			if (existingIndex !== -1) {
				this.previewFrameConfigs[existingIndex] = updatedFrame;
			}
			else {
				this.addPreviewFrameConfig(config);
			}
			if (this.currentFrameConfig.id == config.id) {
				this.currentFrameConfig = updatedFrame;
				this._updateCameraView(this.currentFrameConfig);
			}
		}
		return Promise.resolve();
	}
	switchToPreviewFrame(options: { id: string }): Promise<void> {
		if (this.videoElement) {
			if (!options.id) {
				return Promise.reject('id required');
			}
			let config = this.previewFrameConfigs.filter(config => config.id === options.id);
			if (config.length > 0) {
				this.currentFrameConfig = config[0];
				this._updateCameraView(config[0]);
			}
			else {
				return Promise.reject('id not found');
			}
		}
		return Promise.resolve();
	}
	showPreviewFrame(): Promise<void> {
		if (this.videoElement) {	
			this.videoElement.hidden = false;
		}
		return Promise.resolve();
	}
	hidePreviewFrame(): Promise<void> {
		if (this.videoElement) {	
			this.videoElement.hidden = true;
		}
		return Promise.resolve();
	}
	startRecording(): Promise<void> {
		console.warn('VideoRecorder: No web mock available for startRecording');
		return Promise.resolve();
	}
	stopRecording(): Promise<{ videoUrl: string }> {
		console.warn('VideoRecorder: No web mock available for stopRecording');
		return Promise.resolve({ videoUrl: 'some/file/path' });
	}
	getDuration(): Promise<{ value: number }> {
		return Promise.resolve({ value: 0 });
	}
	addListener(): any {
		console.warn('VideoRecorder: No web mock available for addListener');
	}
}

const VideoRecorder = new VideoRecorderWeb();

export { VideoRecorder };

registerWebPlugin(VideoRecorder);

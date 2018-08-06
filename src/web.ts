import { WebPlugin, registerWebPlugin } from '@capacitor/core';
import { ICapacitorVideoRecorder } from './definitions';

export class CapacitorVideoRecorderWeb extends WebPlugin implements ICapacitorVideoRecorder {

	videoElement: HTMLVideoElement;
	stream: MediaStream;

	pipActive: boolean;

	backgroundStyle: string = `
		width: 100vw;
		height: 100vh;
		object-fit: cover;
		pointer-events: none;
	`;

	pipStyle: string = `
		width: 100px;
		height: 100px;
		object-fit: cover;
		pointer-events: none;
		position: absolute;
		top: 50px;
		left: 50px;
		border-radius: 6px;
	`;

	constructor() {
		super({
			name: 'CapacitorVideoRecorderPlugin',
			platforms: ['web']
		});
	}

	async initialize(): Promise<any> {
		this.videoElement = document.createElement('video');
		this.videoElement.autoplay = true;
		this.videoElement.style.cssText = this.backgroundStyle;
		document.body.appendChild(this.videoElement);
		if (navigator.mediaDevices.getUserMedia) {       
			this.stream = await navigator.mediaDevices.getUserMedia({video: true})
			this.videoElement.srcObject = this.stream;
		}
    	return Promise.resolve();
	}

	async destroy(): Promise<any> {
		this.videoElement.remove();
		this.stream.getTracks().forEach(track => track.stop());
    	return Promise.resolve();
	}
	async show(): Promise<any> {
		this.videoElement.style.display = 'block';
		return Promise.resolve();
	}
	async hide(): Promise<any> {
		this.videoElement.style.display = 'none';
		return Promise.resolve();
	}
	async togglePip(): Promise<any> {
		if (this.pipActive) {
			this.videoElement.style.cssText = this.backgroundStyle;
		}
		else {
			this.videoElement.style.cssText = this.pipStyle;
		}
		this.pipActive = !this.pipActive;
		return Promise.resolve();
	}
	async startRecording(): Promise<any> {
		return Promise.resolve();
	}
	async stopRecording(): Promise<any> {
		return Promise.resolve();
	}
	async getDuration(): Promise<any> {
		return Promise.resolve();
	}
	async toggleCamera(): Promise<any> {
		return Promise.resolve();
	}
}

const CapacitorVideoRecorderPlugin = new CapacitorVideoRecorderWeb();

export { CapacitorVideoRecorderPlugin };

registerWebPlugin(CapacitorVideoRecorderPlugin);

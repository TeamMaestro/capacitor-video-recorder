# Capacitor Video Recorder

A video recording plugin for Capacitor that allows applications to use the native camera and microphone and display the recording interface either below or above their application.

#### Installation
`npm install @teamhive/capacitor-video-recorder`

#### Platform Support
- iOS
- Android

> On a web browser, we will fake the behavior to allow for easier development.

## Example Usage

feature.module.ts
> Import the plugin as defined below to allow the plugin to register correctly to the feature module.
```typescript
import '@teamhive/capacitor-video-recorder';
```

### Initializing Camera

In order to initialize the camera feed (**note**: you are not recording at this point), you must first specify a config to the video recorder.

> Note: To overlay your web UI on-top of the camera output, you must use stackPosition: back and make all layers of your app transparent so that the camera can be seen under the webview.

```typescript
import { VideoRecorderCamera, VideoRecorderPreviewFrame } from '@teamhive/capacitor-video-recorder';

const { VideoRecorder } = Plugins;

const config: VideoRecorderPreviewFrame = {
    id: 'video-record',
    stackPosition: 'front', // 'front' overlays your app', 'back' places behind your app.
    width: 'fill',
    height: 'fill',
    x: 0,
    y: 0,
    borderRadius: 0
};
await VideoRecorder.initialize({
    camera: VideoRecorderCamera.FRONT, // Can use BACK
    previewFrames: [config]
});
```

### Recording

Starts recording against the capture device.

```typescript
VideoRecorder.startRecording();
```

### Stop Recording / Getting Result

Stops the capture device and returns the path of the local video file.

``` typescript
const res = await VideoRecorder.stopRecording();
// The video url is the local file path location of the video output.
return res.videoUrl;
```

### Destroying Camera

Used to disconnect from the capture device and remove any native UI layers that exist.

```typescript
VideoRecorder.destroy();
```

### Example Implementations

|iOS|Android|
|---|---|
|<img src="https://i.gyazo.com/2d7a483eb0693dae23f9d6273962d31d.gif" />|<img src="https://i.gyazo.com/04aa739d4ecde8260dd635cb40d650d0.gif" />|

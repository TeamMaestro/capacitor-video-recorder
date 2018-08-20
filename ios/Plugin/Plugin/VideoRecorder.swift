import Foundation
import AVFoundation
import Capacitor

@objc(CAPVideoRecorderPlugin)
public class CAPVideoRecorderPlugin: CAPPlugin, AVCaptureFileOutputRecordingDelegate {
    
    var capWebView: WKWebView!
    
    var cameraView: CameraView!
    var captureSession: AVCaptureSession?
    var captureVideoPreviewLayer: AVCaptureVideoPreviewLayer?
    var videoOutput: AVCaptureMovieFileOutput?
    var durationTimer: Timer?
    
    var audioLevelTimer: Timer?
    var audioRecorder: AVAudioRecorder?
    
    var cameraInput: AVCaptureDeviceInput?
    
    var currentCamera: Int = 0
    var frontCamera: AVCaptureDevice?
    var backCamera: AVCaptureDevice?
    var quality: Int = 0
    
    var stopRecordingCall: CAPPluginCall?
    
    var previewFrameConfigs: [FrameConfig] = []
    var currentFrameConfig: FrameConfig = FrameConfig(["id": "default"])
    
    /**
     * Capacitor Plugin load
     */
    override public func load() {
        self.capWebView = self.bridge.bridgeDelegate.bridgedWebView
    }
        
    /**
     * AVCaptureFileOutputRecordingDelegate
     */
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        self.durationTimer?.invalidate()
        self.stopRecordingCall?.success(["videoUrl": CAPFileManager.getPortablePath(uri: outputFileURL)! as String])
    }
    
    @objc func levelTimerCallback(_ timer: Timer?) {
        self.audioRecorder?.updateMeters()
        // let peakDecebels: Float = (self.audioRecorder?.peakPower(forChannel: 1))!
        let averagePower: Float = (self.audioRecorder?.averagePower(forChannel: 1))!
        self.notifyListeners("onVolumeInput", data: ["value":averagePower])
    }


	/**
	* Initializes the camera.
	* { camera: Int, quality: Int }
	*/
    @objc func initialize(_ call: CAPPluginCall) {
        if (self.captureSession?.isRunning != true) {
            self.currentCamera = call.getInt("camera", 0)!
            self.quality = call.getInt("quality", 0)!
            let autoShow = call.getBool("autoShow", true)!
            
            for frameConfig in call.getArray("previewFrames", [AnyHashable: Any].self, [ ["id": "default"] ])! {
                self.previewFrameConfigs.append(FrameConfig(frameConfig))
            }
            self.currentFrameConfig = self.previewFrameConfigs.first!
            
            checkAuthorizationStatus(call)
            
            DispatchQueue.main.async {
                do {
                    // Set webview to transparent and set the app window background to white
                    UIApplication.shared.delegate?.window?!.backgroundColor = UIColor.white
                    self.capWebView?.isOpaque = false
                    self.capWebView?.backgroundColor = UIColor.clear
                
                    let deviceDescoverySession = AVCaptureDevice.DiscoverySession.init(
                        deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
                        mediaType: AVMediaType.video,
                        position: AVCaptureDevice.Position.unspecified)
                
                    for device in deviceDescoverySession.devices {
                        if device.position == AVCaptureDevice.Position.back {
                            self.backCamera = device
                        } else if device.position == AVCaptureDevice.Position.front {
                            self.frontCamera = device
                        }
                    }

                    if (self.backCamera == nil) {
                        self.currentCamera = 1
                    }
                    
                    // Create capture session
                    self.captureSession = AVCaptureSession()
                    // Begin configuration
                    self.captureSession?.beginConfiguration()

                    /**
                     * Video file recording capture session
                     */
                    self.captureSession?.usesApplicationAudioSession = true
                    // Add Camera Input
                    self.cameraInput = try createCaptureDeviceInput(currentCamera: self.currentCamera, frontCamera: self.frontCamera, backCamera: self.backCamera)
                    self.captureSession!.addInput(self.cameraInput!)
                    // Add Microphone Input
                    let microphone = AVCaptureDevice.default(for: .audio)
                    if let audioInput = try? AVCaptureDeviceInput(device: microphone!), (self.captureSession?.canAddInput(audioInput))! {
                        self.captureSession!.addInput(audioInput)
                    }
                    // Add Video File Output
                    self.videoOutput = AVCaptureMovieFileOutput()
                    self.captureSession!.addOutput(self.videoOutput!)
                    
                    // Set Video quality
                    switch(self.quality){
                    case 1:
                        self.captureSession?.sessionPreset = AVCaptureSession.Preset.hd1280x720
                        break;
                    case 2:
                        self.captureSession?.sessionPreset = AVCaptureSession.Preset.hd1920x1080
                        break;
                    case 3:
                        self.captureSession?.sessionPreset = AVCaptureSession.Preset.hd4K3840x2160
                        break;
                    case 4:
                        self.captureSession?.sessionPreset = AVCaptureSession.Preset.high
                        break;
                    case 5:
                        self.captureSession?.sessionPreset = AVCaptureSession.Preset.low
                        break;
                    case 6:
                        self.captureSession?.sessionPreset = AVCaptureSession.Preset.cif352x288
                        break;
                    default:
                        self.captureSession?.sessionPreset = AVCaptureSession.Preset.vga640x480
                        break;
                    }
                    
                    // Commit configurations
                    self.captureSession?.commitConfiguration()
                    
                    try? AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryRecord)
                    let settings = [
                        AVSampleRateKey : 44100.0,
                        AVFormatIDKey : kAudioFormatAppleLossless,
                        AVNumberOfChannelsKey : 2,
                        AVEncoderAudioQualityKey : AVAudioQuality.max.rawValue
                    ] as [String : Any]
                    self.audioRecorder = try AVAudioRecorder(url: URL(fileURLWithPath: "/dev/null"), settings: settings)
                    self.audioRecorder?.isMeteringEnabled = true
                    self.audioRecorder?.prepareToRecord()
                    self.audioRecorder?.record()
                    self.audioLevelTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(self.levelTimerCallback(_:)), userInfo: nil, repeats: true)
                    self.audioRecorder?.updateMeters()

                    // Start running sessions
                    self.captureSession!.startRunning()
                    
                    // Initialize camera view
                    self.initializeCameraView()
                    
                    if autoShow {
                        self.cameraView.isHidden = false
                    }
                
                } catch CaptureError.backCameraUnavailable {
                    call.error("Back camera unavailable")
                } catch CaptureError.frontCameraUnavailable {
                    call.error("Front camera unavailable")
                } catch CaptureError.couldNotCaptureInput( _){
                    call.error("Camera unavailable")
                } catch {
                    call.error("Unexpected error")
                }
                call.success()
            }
        }
    }

	/**
	* Destroys the camera.
	*/
    @objc func destroy(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate
            appDelegate?.window?!.backgroundColor = UIColor.black
            
            self.capWebView?.isOpaque = true
            self.capWebView?.backgroundColor = UIColor.white
            if (self.captureSession != nil) {
				// Need to destroy all preview layers
                self.previewFrameConfigs = []
                self.currentFrameConfig = FrameConfig(["id": "default"])
                self.captureSession!.stopRunning()
                self.audioRecorder!.stop()
                self.cameraView.removePreviewLayer()
                self.captureVideoPreviewLayer = nil
                self.cameraView.removeFromSuperview()
                self.videoOutput = nil
                self.cameraView = nil
                self.captureSession = nil
                self.audioRecorder = nil
                self.audioLevelTimer?.invalidate()
                self.currentCamera = 0
                self.frontCamera = nil
                self.backCamera = nil
                self.notifyListeners("onVolumeInput", data: ["value":0])
            }
            call.success()
        }
    }

	/**
	* Toggle between the front facing and rear facing camera.
	*/
    @objc func flipCamera(_ call: CAPPluginCall) {
        if (self.captureSession != nil) {
            var input: AVCaptureDeviceInput? = nil
            do {
                self.currentCamera = self.currentCamera == 0 ? 1 : 0
                input = try createCaptureDeviceInput(currentCamera: self.currentCamera, frontCamera: self.frontCamera, backCamera: self.backCamera)
            } catch CaptureError.backCameraUnavailable {
                self.currentCamera = self.currentCamera == 0 ? 1 : 0
                call.error("Back camera unavailable")
            } catch CaptureError.frontCameraUnavailable {
                self.currentCamera = self.currentCamera == 0 ? 1 : 0
                call.error("Front camera unavailable")
            } catch CaptureError.couldNotCaptureInput( _) {
                self.currentCamera = self.currentCamera == 0 ? 1 : 0
                call.error("Camera unavailable")
            } catch {
                self.currentCamera = self.currentCamera == 0 ? 1 : 0
                call.error("Unexpected error")
            }
            
            if (input != nil) {
                let currentInput = self.cameraInput
                self.captureSession?.beginConfiguration()
                self.captureSession?.removeInput(currentInput!)
                self.captureSession!.addInput(input!)
                self.cameraInput = input
                self.captureSession?.commitConfiguration()
                call.success();
            }
        }
    }

	/**
	* Add a camera preview frame config.
	*/
    @objc func addPreviewFrameConfig(_ call: CAPPluginCall) {
        if (self.captureSession != nil) {
            guard let layerId = call.getString("id") else {
                call.error("Must provide layer id")
                return
            }
			let newFrame = FrameConfig(call.options)
            
            // Check to make sure config doesn't already exist, if it does, edit it instead
            if (self.previewFrameConfigs.index(where: {$0.id == layerId }) == nil) {
                self.previewFrameConfigs.append(newFrame)
            }
            else {
                self.editPreviewFrameConfig(call)
                return
            }
			call.success()
        }
    }

	/**
	* Edit an existing camera frame config.
	*/
    @objc func editPreviewFrameConfig(_ call: CAPPluginCall) {
        if (self.captureSession != nil) {
            guard let layerId = call.getString("id") else {
                call.error("Must provide layer id")
                return
            }
            
            let updatedConfig = FrameConfig(call.options)
            
            // Get existing frame config
            let existingConfig = self.previewFrameConfigs.filter( {$0.id == layerId }).first
            if (existingConfig != nil) {
                let index = self.previewFrameConfigs.index(where: {$0.id == layerId })
                self.previewFrameConfigs[index!] = updatedConfig
            }
            else {
                self.addPreviewFrameConfig(call)
                return
            }

            if (self.currentFrameConfig.id == layerId) {
                // Is set to the current frame, need to update
                DispatchQueue.main.async {
                    self.currentFrameConfig = updatedConfig
                    self.updateCameraView(self.currentFrameConfig)
                }
            }
            call.success()
        }
    }
    
    /**
     * Switch frame configs.
     */
    @objc func switchToPreviewFrame(_ call: CAPPluginCall) {
        if (self.captureSession != nil) {
            guard let layerId = call.getString("id") else {
                call.error("Must provide layer id")
                return
            }
            DispatchQueue.main.async {
                let existingConfig = self.previewFrameConfigs.filter( {$0.id == layerId }).first
                if (existingConfig != nil) {
                    if (existingConfig!.id != self.currentFrameConfig.id) {
                        self.currentFrameConfig = existingConfig!
                        self.updateCameraView(self.currentFrameConfig)
                    }
                }
                else {
                    call.error("Frame config does not exist")
                    return
                }
                call.success()
            }
        }
    }

	/**
	* Show the camera preview frame.
	*/
    @objc func showPreviewFrame(_ call: CAPPluginCall) {
        if (self.captureSession != nil) {
            DispatchQueue.main.async {
                self.cameraView.isHidden = true
                call.success()
            }
        }
    }

	/**
	* Hide the camera preview frame.
	*/
    @objc func hidePreviewFrame(_ call: CAPPluginCall) {
        if (self.captureSession != nil) {
            DispatchQueue.main.async {
                self.cameraView.isHidden = false
                call.success()
            }
        }
    }
    
    func initializeCameraView() {
        self.cameraView = CameraView(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        self.cameraView.isHidden = true
        self.cameraView.autoresizingMask = [.flexibleWidth, .flexibleHeight];
        self.captureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession!)
        self.captureVideoPreviewLayer?.frame = self.cameraView.bounds
        self.cameraView.addPreviewLayer(self.captureVideoPreviewLayer)
        
        self.cameraView.backgroundColor = UIColor.black
        self.cameraView.videoPreviewLayer?.masksToBounds = true
        self.cameraView.clipsToBounds = false
        self.cameraView.layer.backgroundColor = UIColor.clear.cgColor
        
        self.capWebView!.superview!.insertSubview(self.cameraView, belowSubview: self.capWebView!)
        
        self.updateCameraView(self.currentFrameConfig)
    }
    
    func updateCameraView(_ config: FrameConfig) {
        // Set position and dimensions
        let width = config.width as? String == "fill" ? UIScreen.main.bounds.width : config.width as! CGFloat
        let height = config.height as? String == "fill" ? UIScreen.main.bounds.height : config.height as! CGFloat
        self.cameraView.frame = CGRect(x: config.x, y: config.y, width: width, height: height)
        
        // Set stackPosition
        if config.stackPosition == "front" {
            self.capWebView!.superview!.bringSubview(toFront: self.cameraView)
        }
        else if config.stackPosition == "back" {
            self.capWebView!.superview!.sendSubview(toBack: self.cameraView)
        }
        
        // Set decorations
        self.cameraView.videoPreviewLayer?.cornerRadius = config.borderRadius
        self.cameraView.layer.shadowOffset = CGSize.zero
        self.cameraView.layer.shadowColor = config.dropShadow.color
        self.cameraView.layer.shadowOpacity = config.dropShadow.opacity
        self.cameraView.layer.shadowRadius = config.dropShadow.radius
        self.cameraView.layer.shadowPath = UIBezierPath(roundedRect: self.cameraView.bounds, cornerRadius: config.borderRadius).cgPath
    }
    
	/**
	* Start recording.
	*/
    @objc func startRecording(_ call: CAPPluginCall) {
        if (self.captureSession != nil) {
            if (!(videoOutput?.isRecording)!) {
                let tempDir = NSURL.fileURL(withPath:NSTemporaryDirectory(),isDirectory:true)
                var fileName = randomFileName()
                fileName.append(".mp4")
                let fileUrl = NSURL.fileURL(withPath: joinPath(left:tempDir.path,right: fileName));
                videoOutput?.startRecording(to: fileUrl, recordingDelegate: self)

				DispatchQueue.main.async {
            		self.durationTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.updateDuration), userInfo: nil, repeats: true)
        		}
                call.success()
            }
        }
    }

	/**
	* Stop recording.
	*/
    @objc func stopRecording(_ call: CAPPluginCall) {
        if (self.captureSession != nil) {
            if (videoOutput?.isRecording)! {
                self.stopRecordingCall = call
                self.videoOutput!.stopRecording()
            }
        }
    }

	@objc func updateDuration() {
		if (self.videoOutput!.isRecording == true) {
			let duration = self.videoOutput?.recordedDuration;
			if (duration != nil) {
        		self.notifyListeners("onDurationChange", data: ["value":round(CMTimeGetSeconds(duration!))])
			}
		}
    }

	/**
	* Get current recording duration.
	*/
    @objc func getDuration(_ call: CAPPluginCall) {
        if (self.videoOutput!.isRecording == true) {
            let duration = self.videoOutput?.recordedDuration;
            if (duration != nil) {
                call.success(["value":round(CMTimeGetSeconds(duration!))])
            } else {
                call.success(["value":0])
            }
        } else {
            call.success(["value":0])
        }
    }
}

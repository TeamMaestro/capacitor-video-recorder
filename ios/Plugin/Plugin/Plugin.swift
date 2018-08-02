import Foundation
import AVFoundation
import Capacitor

class CameraView: UIView {
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var previewOverlay: CALayer?
    func interfaceOrientationToVideoOrientation(_ orientation : UIInterfaceOrientation) -> AVCaptureVideoOrientation {
        switch (orientation) {
        case UIInterfaceOrientation.portrait:
            return AVCaptureVideoOrientation.portrait;
        case UIInterfaceOrientation.portraitUpsideDown:
            return AVCaptureVideoOrientation.portraitUpsideDown;
        case UIInterfaceOrientation.landscapeLeft:
            return AVCaptureVideoOrientation.landscapeLeft;
        case UIInterfaceOrientation.landscapeRight:
            return AVCaptureVideoOrientation.landscapeRight;
        default:
            return AVCaptureVideoOrientation.portraitUpsideDown;
        }
    }


    override func layoutSubviews() {
        super.layoutSubviews();
        if let sublayers = self.layer.sublayers {
            for layer in sublayers {
                layer.frame = self.bounds
            }
        }
        self.videoPreviewLayer?.connection?.videoOrientation = interfaceOrientationToVideoOrientation(UIApplication.shared.statusBarOrientation);
    }

    func addPreviewLayer(_ previewLayer:AVCaptureVideoPreviewLayer?) {
        previewLayer!.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer!.frame = self.bounds
        self.layer.addSublayer(previewLayer!)
        self.videoPreviewLayer = previewLayer;
        self.previewOverlay = CALayer()
        self.layer.addSublayer(self.previewOverlay!)
    }

    func removePreviewLayer() {
        self.videoPreviewLayer?.removeFromSuperlayer()
        self.videoPreviewLayer = nil
        self.previewOverlay?.removeFromSuperlayer()
        self.previewOverlay = nil
    }
    func hide(){
        self.layer.addSublayer(self.previewOverlay!)
        self.previewOverlay?.isOpaque = true
        self.previewOverlay?.backgroundColor = UIColor.white.cgColor;
    }
    func show(){
        self.previewOverlay?.isOpaque = false
        self.previewOverlay?.backgroundColor = UIColor.clear.cgColor
        self.previewOverlay?.removeFromSuperlayer()
    }
}

enum CaptureError: Error {
    case backCameraUnavailable
    case frontCameraUnavailable
    case couldNotCaptureInput(error: NSError)
}

@objc(CapacitorVideoRecorderPlugin)
public class CapacitorVideoRecorderPlugin: CAPPlugin, AVCaptureFileOutputRecordingDelegate {
    var autoStart: Bool = false
    // CAPPluginCall for stopRecording
    var stopRecordingCall: CAPPluginCall?

    var capWebView: WKWebView!

    var cameraView: CameraView!
    var captureSession: AVCaptureSession?
    var captureVideoPreviewLayer: AVCaptureVideoPreviewLayer?
    var videoOutput: AVCaptureMovieFileOutput?

    var currentCamera: Int = 0
    var frontCamera: AVCaptureDevice?
    var backCamera: AVCaptureDevice?

    var pictureInPicture: Bool = false
    var quality: Int = 0
    // Capacitor plugin load
    override public func load() {
        self.capWebView = self.bridge.bridgeDelegate.bridgedWebView
        self.cameraView = CameraView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        self.cameraView.autoresizingMask = [.flexibleWidth, .flexibleHeight];
    }

    // AVCaptureFileOutputRecordingDelegate
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        self.stopRecordingCall?.success(["videoUrl": CAPFileManager.getPortablePath(uri: outputFileURL)! as String])
    }

    func createCaptureDeviceInput() throws -> AVCaptureDeviceInput {
        var captureDevice: AVCaptureDevice
        if (currentCamera == 0) {
            if (frontCamera != nil){
                captureDevice = frontCamera!
            } else {
                throw CaptureError.frontCameraUnavailable
            }
        } else {
            if (backCamera != nil){
                captureDevice = backCamera!
            } else {
                throw CaptureError.backCameraUnavailable
            }
        }
        let captureDeviceInput: AVCaptureDeviceInput
        do {
            captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
        } catch let error as NSError {
            throw CaptureError.couldNotCaptureInput(error: error)
        }
        return captureDeviceInput
    }

    func makeOpaque() {
        self.cameraView.hide()
    }

   @objc func makeTransparent() {
        self.cameraView.show()
    }

    @objc func initialize(_ call: CAPPluginCall) {
        // TODO: Permission authorization checks
        let videoStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        if (videoStatus == AVAuthorizationStatus.restricted) {
            call.error("Camera access restricted")
            return
        } else if videoStatus == AVAuthorizationStatus.denied {
            call.error("Camera access denied")
            return
        }
        let audioStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.audio)
        if (audioStatus == AVAuthorizationStatus.restricted) {
            call.error("Microphone access restricted")
            return
        } else if audioStatus == AVAuthorizationStatus.denied {
            call.error("Microphone access denied")
            return
        }
        DispatchQueue.main.async {
            do {
                if (self.captureSession?.isRunning != true) {
                    //self.cameraView.backgroundColor = UIColor.white
                    self.capWebView!.superview!.insertSubview(self.cameraView, belowSubview: self.capWebView!)
                    //check if show is on by default

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
                    // older iPods have no back camera
                    if (self.backCamera == nil) {
                        self.currentCamera = 1
                    }
                    let input: AVCaptureDeviceInput
                    input = try self.createCaptureDeviceInput()
                    self.captureSession = AVCaptureSession()
                    self.captureSession!.addInput(input)

                    let microphone = AVCaptureDevice.default(for: .audio)
                    if let audioInput = try? AVCaptureDeviceInput(device: microphone!), (self.captureSession?.canAddInput(audioInput))! {
                        self.captureSession!.addInput(audioInput)
                    }


                    self.videoOutput = AVCaptureMovieFileOutput()
                    self.captureSession!.addOutput(self.videoOutput!)

                    self.captureSession?.beginConfiguration()
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
                    self.captureSession?.commitConfiguration()

                        self.captureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession!)
                    self.captureVideoPreviewLayer?.frame =  self.cameraView.bounds
                        self.cameraView.addPreviewLayer(self.captureVideoPreviewLayer)
                    if(self.autoStart){
                        self.cameraView.show()
                    }
                    self.captureSession!.startRunning()
                    self.autoStart = false
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

    @objc func destroy(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.makeOpaque()
            if (self.captureSession != nil) {
                self.captureSession!.stopRunning()
                self.cameraView.removePreviewLayer()
                self.captureVideoPreviewLayer = nil
                self.videoOutput = nil
                self.captureSession = nil
                self.frontCamera = nil
                self.backCamera = nil
                if (self.pictureInPicture) {
                    self.makeTransparent()
                    self.capWebView!.superview!.sendSubview(toBack: self.cameraView)
                    self.cameraView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    self.cameraView.layer.cornerRadius = 0
                    self.cameraView.layer.borderWidth = 0
                    self.cameraView.clipsToBounds = true
                    self.pictureInPicture = false
                }
            }
            call.success()
        }
    }

    @objc func show(_ call: CAPPluginCall) {
        self.currentCamera =  call.getInt("position") ?? 0
        self.quality = call.getInt("quality") ?? 0
        if (self.captureSession != nil) {
            DispatchQueue.main.async {
                self.autoStart = true;
                self.destroy(call)
                self.initialize(call)
                call.success()
            }
        }
    }

    @objc func hide(_ call: CAPPluginCall) {
        if (self.captureSession != nil) {
            DispatchQueue.main.async {
                self.makeOpaque()
                call.success()
            }
        }
    }
    
    public func joinPath(left: String, right: String) -> String {
        let nsString: NSString = NSString.init(string:left);
        return nsString.appendingPathComponent(right);
    }
    

    public func randomFileName() -> String{
        return NSUUID().uuidString
    }
    
    @objc func startRecording(_ call: CAPPluginCall) {
        if (self.captureSession != nil) {
            if (!(videoOutput?.isRecording)!) {
                let tempDir = NSURL.fileURL(withPath:NSTemporaryDirectory(),isDirectory:true)
                var fileName = randomFileName()
                fileName.append(".mp4")
                let fileUrl = NSURL.fileURL(withPath: joinPath(left:tempDir.path,right: fileName));
                videoOutput?.startRecording(to: fileUrl, recordingDelegate: self)
                call.success()
            }
        }
    }

    @objc func stopRecording(_ call: CAPPluginCall) {
        if (self.captureSession != nil) {
            if (videoOutput?.isRecording)! {
                self.stopRecordingCall = call
                self.videoOutput!.stopRecording()
            }
        }
    }

    @objc func togglePip(_ call: CAPPluginCall) {
        if (self.captureSession != nil) {
            DispatchQueue.main.async {
                if (self.pictureInPicture) {
                    self.makeTransparent()
                    self.capWebView!.superview!.sendSubview(toBack: self.cameraView)
                    self.cameraView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    self.cameraView.layer.cornerRadius = 0
                    self.cameraView.layer.borderWidth = 0
                    self.cameraView.clipsToBounds = true
                    self.pictureInPicture = false
                } else {
                    self.makeOpaque()
                    self.capWebView!.superview!.bringSubview(toFront: self.cameraView)
                    self.cameraView.frame = CGRect(x: 20, y: 50, width: 80, height: 120)
                    self.cameraView.layer.cornerRadius = 10
                    self.cameraView.clipsToBounds = true
                    self.cameraView.layer.borderWidth = 1
                    self.cameraView.layer.borderColor = UIColor.init(red:255/255, green:255/255, blue:255/255, alpha: 1).cgColor
                    self.pictureInPicture = true
                }
                call.success([
                    "pictureInPicture": self.pictureInPicture
                    ])
            }
        } else {
            call.success()
        }
    }

    @objc func toggleCamera(_ call: CAPPluginCall){
        self.destroy(call)
        print(self.currentCamera)
        if(self.currentCamera == 0){
            self.currentCamera = 1
        }else{
            self.currentCamera = 0
        }
        print(self.currentCamera)
        self.autoStart = true
        self.initialize(call)

    }
    @objc func getDuration(_ call: CAPPluginCall){
        if(self.videoOutput!.isRecording == true){
            let duration = self.videoOutput?.recordedDuration;
            if(duration != nil){
                call.success(["value":round(CMTimeGetSeconds(duration!))])
            }else{
                call.success(["value":0])
            }

        }else{
            call.success(["value":0])
        }

    }
    func updatePosition(position: Int){
        switch(position){
        case 1:
            self.currentCamera = 1
            break;
        default:
            self.currentCamera = 0
            break;
        }
    }

    @objc func setPosition(_ call: CAPPluginCall){
        self.currentCamera =  call.getInt("position") ?? 0
        self.destroy(call)
        self.initialize(call)
    }
    @objc func setQuality(_ call: CAPPluginCall){
        self.quality = call.getInt("quality") ?? 0
        self.destroy(call)
        self.initialize(call)
    }
}

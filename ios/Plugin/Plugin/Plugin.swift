import Foundation
import AVFoundation
import Capacitor

class CameraView: UIView {
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    
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
    }
    
    func removePreviewLayer() {
        self.videoPreviewLayer?.removeFromSuperlayer()
        self.videoPreviewLayer = nil
    }
}

enum CaptureError: Error {
    case backCameraUnavailable
    case frontCameraUnavailable
    case couldNotCaptureInput(error: NSError)
}

@objc(CapacitorVideoRecorderPlugin)
public class CapacitorVideoRecorderPlugin: CAPPlugin, AVCaptureFileOutputRecordingDelegate {
    
    // CAPPluginCall for stopRecording
    var stopRecordingCall: CAPPluginCall?
    
    var capWebView: WKWebView!
    
    var cameraView: CameraView!
    var captureSession: AVCaptureSession?
    var captureVideoPreviewLayer: AVCaptureVideoPreviewLayer?
    var videoOutput: AVCaptureMovieFileOutput?
    
    var currentCamera: Int = 0;
    var frontCamera: AVCaptureDevice?
    var backCamera: AVCaptureDevice?
    
    var pictureInPicture: Bool = false
    
    // Capacitor plugin load
    override public func load() {
        self.capWebView = self.bridge.bridgeDelegate.bridgedWebView
        self.cameraView = CameraView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        self.cameraView.autoresizingMask = [.flexibleWidth, .flexibleHeight];
    }
    
    // AVCaptureFileOutputRecordingDelegate
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        stopRecordingCall?.success([
            "videoUrl": CAPFileManager.getPortablePath(uri: outputFileURL) as Any
        ])
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
        self.capWebView?.isOpaque = true
        self.capWebView?.backgroundColor = UIColor.white
    }
    
    func makeTransparent() {
        self.capWebView?.isOpaque = false
        self.capWebView?.backgroundColor = UIColor.clear
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
                    self.cameraView.backgroundColor = UIColor.white
                    self.capWebView!.superview!.insertSubview(self.cameraView, belowSubview: self.capWebView!)
                    
                    //check if show is on by default
                    self.makeTransparent()
                    
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
                    
                    self.captureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession!)
                    self.cameraView.addPreviewLayer(self.captureVideoPreviewLayer)
                    self.captureSession!.startRunning()
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
                self.currentCamera = 0
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
        if (self.captureSession != nil) {
            DispatchQueue.main.async {
                self.makeTransparent()
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
    
    @objc func startRecording(_ call: CAPPluginCall) {
        if (self.captureSession != nil) {
            if (!(videoOutput?.isRecording)!) {
                let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileUrl = paths.appendingPathComponent("output.mp4")
                try? FileManager.default.removeItem(at: fileUrl)
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
}

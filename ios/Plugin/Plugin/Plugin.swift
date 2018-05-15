import Foundation
import AVFoundation
import Capacitor

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitor.ionicframework.com/docs/plugins/ios
 */
@objc(CapacitorVideoRecorderPlugin)
public class CapacitorVideoRecorderPlugin: CAPPlugin, AVCaptureFileOutputRecordingDelegate {
    
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        fileCall?.success([
            "fileUrl": outputFileURL
        ])
    }
    
    class CameraView: UIView {
        var videoPreviewLayer:AVCaptureVideoPreviewLayer?
        
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
            self.videoPreviewLayer!.removeFromSuperlayer()
            self.videoPreviewLayer = nil
        }
    }

    
    var fileCall: CAPPluginCall?
    
    var cameraView: CameraView!
    var captureSession:AVCaptureSession?
    var captureVideoPreviewLayer:AVCaptureVideoPreviewLayer?
    // var metaOutput: AVCaptureMetadataOutput?
    var videoOutput: AVCaptureMovieFileOutput?
    
    var currentCamera: Int = 0;
    var frontCamera: AVCaptureDevice?
    var backCamera: AVCaptureDevice?
    
    var paused: Bool = false
    
    var thumbnail: Bool = false
    

    
    enum VideoRecorderError: Int32 {
        case unexpected_error = 0,
        camera_access_denied = 1,
        camera_access_restricted = 2,
        back_camera_unavailable = 3,
        front_camera_unavailable = 4,
        camera_unavailable = 5,
        scan_canceled = 6,
        light_unavailable = 7,
        open_settings_unavailable = 8
    }
    
    enum CaptureError: Error {
        case backCameraUnavailable
        case frontCameraUnavailable
        case couldNotCaptureInput(error: NSError)
    }

	override public func load() {
        self.cameraView = CameraView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height))
        self.cameraView.autoresizingMask = [.flexibleWidth, .flexibleHeight];
    }
 
    func sendErrorCode(call: CAPPluginCall, error: VideoRecorderError){
        call.error(String(error.rawValue))
    }
    
    // utility method
    func backgroundThread(delay: Double = 0.0, background: (() -> Void)? = nil, completion: (() -> Void)? = nil) {
        if #available(iOS 8.0, *) {
            DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async {
                if (background != nil) {
                    background!()
                }
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + delay * Double(NSEC_PER_SEC)) {
                    if(completion != nil){
                        completion!()
                    }
                }
            }
        } else {
            // Fallback for iOS < 8.0
            if(background != nil){
                background!()
            }
            if(completion != nil){
                completion!()
            }
        }
    }

    func prepScanner(call: CAPPluginCall) -> Bool{
        let status = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        if (status == AVAuthorizationStatus.restricted) {
            self.sendErrorCode(call: call, error: VideoRecorderError.camera_access_restricted)
            return false
        } else if status == AVAuthorizationStatus.denied {
            self.sendErrorCode(call: call, error: VideoRecorderError.camera_access_denied)
            return false
        }
        do {
            if (captureSession?.isRunning != true){
                cameraView.backgroundColor = UIColor.white
                self.bridge.bridgeDelegate.bridgedWebView!.superview!.insertSubview(cameraView, belowSubview: self.bridge.bridgeDelegate.bridgedWebView!)
                
                
                // TODO use AVCaptureDevice.DiscoverySession
                let availableVideoDevices = AVCaptureDevice.devices(for: AVMediaType.video)
                for device in availableVideoDevices {
                    if device.position == AVCaptureDevice.Position.back {
                        backCamera = device
                    }
                    else if device.position == AVCaptureDevice.Position.front {
                        frontCamera = device
                    }
                }
                // older iPods have no back camera
                if(backCamera == nil){
                    currentCamera = 1
                }
                let input: AVCaptureDeviceInput
                input = try self.createCaptureDeviceInput()
                captureSession = AVCaptureSession()
                captureSession!.addInput(input)
                
                let microphone = AVCaptureDevice.default(for: .audio)
                if let audioInput = try? AVCaptureDeviceInput(device: microphone!), (self.captureSession?.canAddInput(audioInput))! {
                    captureSession!.addInput(audioInput)
                }
                
                videoOutput = AVCaptureMovieFileOutput()
                captureSession!.addOutput(videoOutput!)
                
                
                captureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
                cameraView.addPreviewLayer(captureVideoPreviewLayer)
                captureSession!.startRunning()
            }
            return true
        } catch CaptureError.backCameraUnavailable {
            self.sendErrorCode(call: call, error: VideoRecorderError.back_camera_unavailable)
        } catch CaptureError.frontCameraUnavailable {
            self.sendErrorCode(call: call, error: VideoRecorderError.front_camera_unavailable)
        } catch CaptureError.couldNotCaptureInput(let error){
            print(error.localizedDescription)
            self.sendErrorCode(call: call, error: VideoRecorderError.camera_unavailable)
        } catch {
            self.sendErrorCode(call: call, error: VideoRecorderError.unexpected_error)
        }
        return false
    }
    
    func createCaptureDeviceInput() throws -> AVCaptureDeviceInput {
        var captureDevice: AVCaptureDevice
        if(currentCamera == 0){
            if(frontCamera != nil){
                captureDevice = frontCamera!
            } else {
                throw CaptureError.frontCameraUnavailable
            }
        } else {
            if(backCamera != nil){
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
    
    func makeOpaque(){
        self.bridge.bridgeDelegate.bridgedWebView?.isOpaque = true
        self.bridge.bridgeDelegate.bridgedWebView?.backgroundColor = UIColor.white
    }

    func makeTransparent(){
		self.bridge.bridgeDelegate.bridgedWebView?.isOpaque = false
		self.bridge.bridgeDelegate.bridgedWebView?.backgroundColor = UIColor.clear
    }
    
    func boolToNumberString(bool: Bool) -> String{
        if(bool) {
            return "1"
        } else {
            return "0"
        }
    }
    
    @objc func initialize(_ call: CAPPluginCall) {        
        let status = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        if (status == AVAuthorizationStatus.notDetermined) {
            // Request permission before preparing scanner
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (granted) -> Void in
                // attempt to prepScanner only after the request returns
                self.backgroundThread(delay: 0, completion: {
                    if(self.prepScanner(call: call)){
                        self.getStatus(call)
                    }
                })
            })
        } else {
            self.backgroundThread(delay: 0, completion: {
                if(self.prepScanner(call: call)){
                    self.getStatus(call)
                }
            })
        }
    }
    
    @objc func show(_ call: CAPPluginCall) {
        self.backgroundThread(delay: 0, completion: {
			self.makeTransparent()
            self.getStatus(call)
        })
    }

    @objc func hide(_ call: CAPPluginCall) {
        self.backgroundThread(delay: 0, completion: {
            self.makeOpaque()
            self.getStatus(call)
        })
    }

    @objc func startRecording(_ call: CAPPluginCall) {
		let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
		let fileUrl = paths.appendingPathComponent("output.mp4")
		try? FileManager.default.removeItem(at: fileUrl)
        videoOutput?.startRecording(to: fileUrl, recordingDelegate: self)
		self.getStatus(call)
    }

    @objc func stopRecording(_ call: CAPPluginCall) {
        self.fileCall = call
		self.videoOutput!.stopRecording()
    }
    
    @objc func toggle(_ call: CAPPluginCall) {
		self.backgroundThread(delay: 0, completion: {
            if(self.thumbnail){
				self.makeTransparent()
                self.bridge.bridgeDelegate.bridgedWebView!.superview!.sendSubview(toBack: self.cameraView)
				self.cameraView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
				self.cameraView.layer.cornerRadius = 0
				self.cameraView.layer.borderWidth = 0
				self.cameraView.clipsToBounds = true
				self.thumbnail = false
			} else {
				self.makeOpaque()
				self.bridge.bridgeDelegate.bridgedWebView!.superview!.bringSubview(toFront: self.cameraView)
				self.cameraView.frame = CGRect(x: 20, y: 50, width: 80, height: 120)
				self.cameraView.layer.cornerRadius = 10
				self.cameraView.clipsToBounds = true
				self.cameraView.layer.borderWidth = 1
				self.cameraView.layer.borderColor = UIColor.init(red:255/255, green:255/255, blue:255/255, alpha: 1).cgColor
				self.thumbnail = true
			}

            call.success([
                "value": self.thumbnail
            ])
        })
    }
    
    @objc func getStatus(_ call: CAPPluginCall) {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video);
        
        var authorized = false
        if(authorizationStatus == AVAuthorizationStatus.authorized){
            authorized = true
        }
        
        var denied = false
        if(authorizationStatus == AVAuthorizationStatus.denied){
            denied = true
        }
        
        var restricted = false
        if(authorizationStatus == AVAuthorizationStatus.restricted){
            restricted = true
        }
        
        var prepared = false
        if(captureSession?.isRunning == true){
            prepared = true
        }
        
        var previewing = false
        if(captureVideoPreviewLayer != nil){
            previewing = (captureVideoPreviewLayer!.connection?.isEnabled)!
        }
        
        var showing = false
        //if(self.bridge.bridgeDelegate.bridgedWebView!.backgroundColor == UIColor.clear){
        //    showing = true
        //}
        
        var lightEnabled = false
        if(backCamera?.torchMode == AVCaptureDevice.TorchMode.on){
            lightEnabled = true
        }
        
        var canOpenSettings = false
        if #available(iOS 8.0, *) {
            canOpenSettings = true
        }
        
        var canEnableLight = false
        if(backCamera?.hasTorch == true && backCamera?.isTorchAvailable == true && backCamera?.isTorchModeSupported(AVCaptureDevice.TorchMode.on) == true){
            canEnableLight = true
        }
        
        var canChangeCamera = false;
        if(backCamera != nil && frontCamera != nil){
            canChangeCamera = true
        }
        
        let status = [
            "authorized": boolToNumberString(bool: authorized),
            "denied": boolToNumberString(bool: denied),
            "restricted": boolToNumberString(bool: restricted),
            "prepared": boolToNumberString(bool: prepared),
            "previewing": boolToNumberString(bool: previewing),
            "showing": boolToNumberString(bool: showing),
            "lightEnabled": boolToNumberString(bool: lightEnabled),
            "canOpenSettings": boolToNumberString(bool: canOpenSettings),
            "canEnableLight": boolToNumberString(bool: canEnableLight),
            "canChangeCamera": boolToNumberString(bool: canChangeCamera),
            "currentCamera": String(currentCamera)
        ]
        
        call.success(status)
    }
}

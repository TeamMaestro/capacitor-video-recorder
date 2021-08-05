import Foundation
import AVFoundation
import Capacitor

extension UIColor {
    convenience init(fromHex hex: String) {
        var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }
        var rgbValue:UInt32 = 0
        Scanner(string: cString).scanHexInt32(&rgbValue)
        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}

public class FrameConfig {
    var id: String
    var stackPosition: String
    var x: CGFloat
    var y: CGFloat
    var width: Any
    var height: Any
    var borderRadius: CGFloat
    var dropShadow: DropShadow
    
    init(_ options: [AnyHashable: Any] = [:]) {
        self.id = options["id"] as! String
        self.stackPosition = options["stackPosition"] as? String ?? "back"
        self.x = options["x"] as? CGFloat ?? 0
        self.y = options["y"] as? CGFloat ?? 0
        self.width = options["width"] ?? "fill"
        self.height = options["height"] ?? "fill"
        self.borderRadius = options["borderRadius"] as? CGFloat ?? 0
        self.dropShadow = DropShadow(options["dropShadow"] as? [AnyHashable: Any] ?? [:])
    }
    
    class DropShadow {
        var opacity: Float
        var radius: CGFloat
        var color: CGColor
        init(_ options: [AnyHashable: Any]) {
            self.opacity = (options["opacity"] as? NSNumber ?? 0).floatValue
            self.radius = options["radius"] as? CGFloat ?? 0
            self.color = UIColor(fromHex: options["color"] as? String ?? "#000000").cgColor
        }
    }
}

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

public func checkAuthorizationStatus(_ call: CAPPluginCall) -> Bool {
    let videoStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
    if (videoStatus == AVAuthorizationStatus.restricted) {
        call.reject("Camera access restricted")
        return false
    } else if videoStatus == AVAuthorizationStatus.denied {
        call.reject("Camera access denied")
        return false
    }
    let audioStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.audio)
    if (audioStatus == AVAuthorizationStatus.restricted) {
        call.reject("Microphone access restricted")
        return false
    } else if audioStatus == AVAuthorizationStatus.denied {
        call.reject("Microphone access denied")
        return false
    }
    return true
}

enum CaptureError: Error {
    case backCameraUnavailable
    case frontCameraUnavailable
    case couldNotCaptureInput(error: NSError)
}

/**
	* Create capture input
	*/
public func createCaptureDeviceInput(currentCamera: Int, frontCamera: AVCaptureDevice?, backCamera: AVCaptureDevice?) throws -> AVCaptureDeviceInput {
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

public func joinPath(left: String, right: String) -> String {
    let nsString: NSString = NSString.init(string:left);
    return nsString.appendingPathComponent(right);
}

public func randomFileName() -> String {
    return NSUUID().uuidString
}

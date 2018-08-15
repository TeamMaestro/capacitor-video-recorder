#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

// Define the plugin using the CAP_PLUGIN Macro, and
// each method the plugin supports using the CAP_PLUGIN_METHOD macro.
CAP_PLUGIN(CAPVideoRecorderPlugin, "VideoRecorder",
	CAP_PLUGIN_METHOD(initialize, CAPPluginReturnPromise);
	CAP_PLUGIN_METHOD(destroy, CAPPluginReturnPromise);
	CAP_PLUGIN_METHOD(flipCamera, CAPPluginReturnPromise);
	CAP_PLUGIN_METHOD(addPreviewFrameConfig, CAPPluginReturnPromise);
	CAP_PLUGIN_METHOD(editPreviewFrameConfig, CAPPluginReturnPromise);
	CAP_PLUGIN_METHOD(switchToPreviewFrame, CAPPluginReturnPromise);
	CAP_PLUGIN_METHOD(showPreviewFrame, CAPPluginReturnPromise);
	CAP_PLUGIN_METHOD(hidePreviewFrame, CAPPluginReturnPromise);
	CAP_PLUGIN_METHOD(startRecording, CAPPluginReturnPromise);
	CAP_PLUGIN_METHOD(stopRecording, CAPPluginReturnPromise);
	CAP_PLUGIN_METHOD(getDuration, CAPPluginReturnPromise);
)

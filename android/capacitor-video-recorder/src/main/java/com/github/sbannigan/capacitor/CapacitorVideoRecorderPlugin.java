package com.github.sbannigan.capacitor;

import android.graphics.Color;
import android.net.Uri;
import android.view.ViewGroup;
import android.widget.FrameLayout;

import com.getcapacitor.FileUtils;
import com.getcapacitor.JSObject;
import com.getcapacitor.NativePlugin;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;

import co.fitcom.fancycamera.CameraEventListenerUI;
import co.fitcom.fancycamera.EventType;
import co.fitcom.fancycamera.FancyCamera;
import co.fitcom.fancycamera.PhotoEvent;
import co.fitcom.fancycamera.VideoEvent;

@NativePlugin()
public class CapacitorVideoRecorderPlugin extends Plugin {
    private FancyCamera fancyCamera;
    private PluginCall call;

    PluginCall getCall() {
        return call;
    }

    @Override
    public void load() {
        super.load();
        fancyCamera = new FancyCamera(this.getContext());
        fancyCamera.setListener(new CameraEventListenerUI() {
            @Override
            public void onPhotoEventUI(PhotoEvent event) {

            }

            @Override
            public void onVideoEventUI(VideoEvent event) {
                if (event.getType() == EventType.INFO &&
                        event
                                .getMessage().contains(VideoEvent.EventInfo.RECORDING_FINISHED.toString())) {
                    if (getCall() != null) {
                        JSObject object = new JSObject();
                        String path = FileUtils.getPortablePath(getContext(), Uri.fromFile(event.getFile()));
                        object.put("videoUrl", path);
                        getCall().resolve(object);
                    } else {
                        if (event.getType() == co.fitcom.fancycamera.EventType.ERROR) {
                            getCall().reject(event.getMessage());
                        }
                    }

                }
            }
        });
        FrameLayout.LayoutParams cameraPreviewParams = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT);
        ((ViewGroup) this.bridge.getWebView().getParent()).addView(fancyCamera, cameraPreviewParams);
        this.bridge.getWebView().bringToFront();
        fancyCamera.start();

    }

    @PluginMethod()
    public void initialize(PluginCall call) {
        fancyCamera.requestPermission();
        call.success();
    }

    @PluginMethod()
    public void destroy(PluginCall call) {
        makeOpaque();
        fancyCamera.release();
        call.success();
    }

    private void makeOpaque() {
        this.bridge.getWebView().setBackgroundColor(Color.WHITE);
    }

    @PluginMethod()
    public void show(PluginCall call) {
        int position = call.getInt("position");
        int quality = call.getInt("quality");
        fancyCamera.setCameraPosition(position);
        fancyCamera.setQuality(quality);
        this.bridge.getWebView().setBackgroundColor(Color.argb(0, 0, 0, 0));
        fancyCamera.start();
        call.success();
    }

    @PluginMethod()
    public void hide(PluginCall call) {
        makeOpaque();
        fancyCamera.stop();
        call.success();
    }

    @PluginMethod()
    public void togglePip(PluginCall call) {

    }

    @PluginMethod()
    public void startRecording(PluginCall call) {
        fancyCamera.startRecording();
        call.success();
    }

    @PluginMethod()
    public void stopRecording(PluginCall call) {
        this.call = call;
        fancyCamera.stopRecording();
    }

    @PluginMethod()
    public void toggleCamera(PluginCall call) {
        fancyCamera.toggleCamera();
        call.success();
    }

    @PluginMethod()
    public void getDuration(PluginCall call) {
        JSObject object = new JSObject();
        object.put("value", fancyCamera.getDuration());
        call.resolve(object);
    }

    @PluginMethod()
    public void setPosition(PluginCall call) {
        int position = call.getInt("position");
        fancyCamera.setCameraPosition(position);
    }

    @PluginMethod()
    public void setQuality(PluginCall call) {
        int quality = call.getInt("quality");
        fancyCamera.setQuality(quality);
    }
}

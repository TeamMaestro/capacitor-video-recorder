package com.github.triniwiz.capacitor;

import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.view.ViewGroup;
import android.widget.FrameLayout;

import com.getcapacitor.Bridge;
import com.getcapacitor.JSObject;
import com.getcapacitor.NativePlugin;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;

import co.fitcom.fancycamera.CameraEventListener;
import co.fitcom.fancycamera.EventType;
import co.fitcom.fancycamera.FancyCamera;
import co.fitcom.fancycamera.PhotoEvent;
import co.fitcom.fancycamera.VideoEvent;

@NativePlugin()
public class CapacitorVideoRecorderPlugin extends Plugin {
    FancyCamera fancyCamera;
    PluginCall call;

    @Override
    public void load() {
        super.load();
        fancyCamera = new FancyCamera(this.getContext());
        fancyCamera.setListener(new CameraEventListener() {
            @Override
            public void onPhotoEvent(PhotoEvent event) {

            }

            @Override
            public void onVideoEvent(VideoEvent event) {
                if (call != null) {

                    if (event.getType() == EventType.INFO &&
                            event
                                    .getMessage().contains(VideoEvent.EventInfo.RECORDING_FINISHED.toString())) {

                        JSObject object = new JSObject();
                        object.put("videoUrl", event.getFile().getPath());
                        call.success(object);
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
        this.bridge.getWebView().setBackgroundColor(Color.TRANSPARENT);
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
        fancyCamera.stopRecording();
        call.success();
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
        call.success(object);
    }

    @PluginMethod()
    public void setPosition(PluginCall call){
    int position = call.getInt("position");
    fancyCamera.setCameraPosition(position);
    }

    @PluginMethod()
    public void setQuality(PluginCall call){
        int quality = call.getInt("quality");
        fancyCamera.setQuality(quality);
    }
}
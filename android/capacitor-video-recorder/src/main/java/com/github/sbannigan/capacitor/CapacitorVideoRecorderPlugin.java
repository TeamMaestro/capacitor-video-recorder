package com.github.sbannigan.capacitor;

import android.content.pm.PackageManager;
import android.graphics.Color;
import android.net.Uri;
import android.util.DisplayMetrics;
import android.view.ViewGroup;
import android.widget.FrameLayout;

import com.getcapacitor.FileUtils;
import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.NativePlugin;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;

import org.json.JSONException;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import co.fitcom.fancycamera.CameraEventListenerUI;
import co.fitcom.fancycamera.EventType;
import co.fitcom.fancycamera.FancyCamera;
import co.fitcom.fancycamera.PhotoEvent;
import co.fitcom.fancycamera.VideoEvent;

@NativePlugin(
        requestCodes = {
                CapacitorVideoRecorderPlugin.REQUEST_CODE
        }
)
public class CapacitorVideoRecorderPlugin extends Plugin {
    static final int REQUEST_CODE = 868;
    private FancyCamera fancyCamera;
    private PluginCall call;
    private HashMap<String,FrameConfig> previewFrameConfigs = new HashMap<>();
    private FrameConfig currentFrameConfig;
    private FancyCamera.CameraPosition cameraPosition = FancyCamera.CameraPosition.BACK;

    PluginCall getCall() {
        return call;
    }

    @Override
    protected void handleRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.handleRequestPermissionsResult(requestCode, permissions, grantResults);
        if(grantResults[0] == PackageManager.PERMISSION_GRANTED && grantResults[1] == PackageManager.PERMISSION_GRANTED){
            fancyCamera.start();
            updateCameraView(currentFrameConfig);
        }
    }

    @Override
    public void load() {
        super.load();
        JSObject defaultFrame = new JSObject();
        defaultFrame.put("id", "default");
        currentFrameConfig = new FrameConfig(defaultFrame);
    }

    @PluginMethod()
    public void initialize(PluginCall call) {
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

        fancyCamera.setCameraPosition(call.getInt("camera", 0));


        JSObject defaultFrame = new JSObject();
        defaultFrame.put("id", "default");
        JSArray defaultArray = new JSArray();
        defaultArray.put(defaultFrame);
        JSArray array = call.getArray("previewFrames", defaultArray);
        int size = array.length();
        for (int i = 0; i > size; i++) {
            try {
                FrameConfig config = (FrameConfig) array.get(i);
                previewFrameConfigs.put(config.id,config);
            } catch (JSONException ignored) {

            }
        }


        if(fancyCamera.hasPermission()){
            fancyCamera.start();
            updateCameraView(currentFrameConfig);
        }else{
            fancyCamera.requestPermission();
        }

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
    public void showPreviewFrame(PluginCall call) {
        int position = call.getInt("position");
        int quality = call.getInt("quality");
        fancyCamera.setCameraPosition(position);
        fancyCamera.setQuality(quality);
        this.bridge.getWebView().setBackgroundColor(Color.argb(0, 0, 0, 0));
        fancyCamera.start();
        call.success();
    }

    @PluginMethod()
    public void hidePreviewFrame(PluginCall call) {
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
    public void flipCamera(PluginCall call) {
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


    @PluginMethod()
    public void addPreviewFrameConfig(PluginCall call) {
        if (fancyCamera.cameraStarted()) {
            String layerId = call.getString("id");
            if (layerId.isEmpty()) {
                call.error("Must provide layer id");
                return;
            }

            FrameConfig config = new FrameConfig(call.getData());

            if (previewFrameConfigs.containsKey(layerId)) {
                editPreviewFrameConfig(call);
                return;
            } else {
                previewFrameConfigs.put(layerId, config);
            }
            call.success();
        }
    }

    @PluginMethod()
    public void editPreviewFrameConfig(PluginCall call) {
        if (fancyCamera.cameraStarted()) {
            String layerId = call.getString("id");
            if (layerId.isEmpty()) {
                call.error("Must provide layer id");
                return;
            }

            FrameConfig updatedConfig = new FrameConfig(call.getData());
            previewFrameConfigs.put(layerId, updatedConfig);

            if (currentFrameConfig.id.equals(layerId)) {
                currentFrameConfig = updatedConfig;
                updateCameraView(currentFrameConfig);
            }

            call.success();
        }
    }


    @PluginMethod()
    public void switchToPreviewFrame(PluginCall call) {
        if (fancyCamera.cameraStarted()) {
            String layerId = call.getString("id");
            if (layerId.isEmpty()) {
                call.error("Must provide layer id");
                return;
            }
            FrameConfig existingConfig = previewFrameConfigs.get(layerId);
            if (existingConfig != null) {
                if (!existingConfig.id.equals(currentFrameConfig.id)) {
                    currentFrameConfig = existingConfig;
                    updateCameraView(currentFrameConfig);
                }

            } else {
                call.error("Frame config does not exist");
                return;
            }
            call.success();
        }
    }

    private int getPixels(int value) {
        return (int) (value * getContext().getResources().getDisplayMetrics().density + 0.5f);
    }

    private void updateCameraView(FrameConfig frameConfig) {
        DisplayMetrics displayMetrics = new DisplayMetrics();
        getActivity().getWindowManager().getDefaultDisplay().getMetrics(displayMetrics);
        int deviceHeight = displayMetrics.heightPixels;
        int deviceWidth = displayMetrics.widthPixels;
        int width;
        int height;
        ViewGroup.LayoutParams oldParams = fancyCamera.getLayoutParams();
        if (frameConfig.width == -1) {
            width = deviceWidth;
        } else {
            width = getPixels(frameConfig.width);
        }

        if (frameConfig.height == -1) {
            height = deviceHeight;
        } else {
            height = getPixels(frameConfig.height);
        }

        oldParams.width = width;
        oldParams.height = height;
        fancyCamera.setY(frameConfig.y);
        fancyCamera.setX(frameConfig.x);
        fancyCamera.setElevation(9);


        if (frameConfig.stackPosition.equals("front")) {
            fancyCamera.bringToFront();
        } else if (frameConfig.stackPosition.equals("back")) {
            getBridge().getWebView().bringToFront();
        }
    }


    class FrameConfig {
        String id;
        String stackPosition;
        float x;
        float y;
        int width;
        int height;
        float borderRadius;
        DropShadow dropShadow;

        FrameConfig(JSObject object) {
            id = object.getString("id");
            stackPosition = object.getString("stackPosition", "back");
            x = object.getInteger("x", 0).floatValue();
            y = object.getInteger("y", 0).floatValue();
            width = object.getInteger("width", -1);
            height = object.getInteger("height", -1);
            borderRadius = object.getInteger("borderRadius", 0);
            dropShadow = new DropShadow(object.getJSObject("dropShadow"));
        }

        class DropShadow {
            float opacity;
            float radius;
            Color color;

            DropShadow(JSObject object) {
                opacity = object.getInteger("opacity", 0).floatValue();
                radius = object.getInteger("radius", 0).floatValue();
            }
        }
    }
}

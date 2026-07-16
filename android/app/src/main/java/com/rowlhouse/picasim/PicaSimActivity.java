package com.rowlhouse.picasim;

import android.view.InputDevice;
import android.view.KeyEvent;
import android.view.MotionEvent;

import org.libsdl.app.SDLActivity;
import org.libsdl.app.SDLControllerManager;

/**
 * PicaSim Android Activity - extends SDLActivity for SDL2 integration.
 * SDLActivity handles the native library loading, GL surface creation,
 * and event dispatching to the native C++ code.
 */
public class PicaSimActivity extends SDLActivity {

    /**
     * Called by SDL to determine which shared libraries to load.
     */
    @Override
    protected String[] getLibraries() {
        return new String[]{
            "SDL2",
            "openal",
            "PicaSim"
        };
    }

    // On Meta Quest the OpenXR runtime consumes gamepad events before they
    // reach the SDL surface (a known Horizon OS issue that also affects
    // Unreal/Unity: the events are eaten during input predispatch), so
    // gamepad input only works intermittently. Intercept events at the
    // Activity dispatch level - the earliest app-side hook - and feed
    // joystick/gamepad events straight into SDL. Quest flavor only: on
    // phones the normal SDL path works and stays untouched.

    private static boolean isQuestBuild() {
        return BuildConfig.FLAVOR.equals("quest");
    }

    private static boolean isJoystickEvent(int source) {
        return (source & InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK
            || (source & InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD;
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        if (isQuestBuild() && isJoystickEvent(event.getSource())
            && SDLControllerManager.isDeviceSDLJoystick(event.getDeviceId())) {
            if (event.getAction() == KeyEvent.ACTION_DOWN) {
                SDLControllerManager.onNativePadDown(event.getDeviceId(), event.getKeyCode());
                return true;
            } else if (event.getAction() == KeyEvent.ACTION_UP) {
                SDLControllerManager.onNativePadUp(event.getDeviceId(), event.getKeyCode());
                return true;
            }
        }
        return super.dispatchKeyEvent(event);
    }

    @Override
    public boolean dispatchGenericMotionEvent(MotionEvent event) {
        if (isQuestBuild() && isJoystickEvent(event.getSource())
            && SDLControllerManager.isDeviceSDLJoystick(event.getDeviceId())) {
            return SDLControllerManager.handleJoystickMotionEvent(event);
        }
        return super.dispatchGenericMotionEvent(event);
    }
}

package com.parrot.freeflight.remotecontrollers;

import android.view.KeyEvent;

public abstract class ButtonPressedController
        implements ButtonController
{
    final int buttonToTrack;
    public boolean pressed;

    public ButtonPressedController(int theKeyCodeToTrack)
    {
        this.buttonToTrack = theKeyCodeToTrack;
        this.pressed = false;
    }

    public final boolean onKeyEvent(KeyEvent theEvent)
    {
        final int keyCode = theEvent.getKeyCode();

        if (keyCode == buttonToTrack) {
            if (theEvent.getAction() == KeyEvent.ACTION_DOWN) {
                if (!this.pressed) {
                    onButtonPressed();
                    this.pressed = true;
                }
            } else if (theEvent.getAction() == KeyEvent.ACTION_UP) {
                if (this.pressed) {
                    onButtonReleased();
                    this.pressed = false;
                }
            }
            return true;
        } else {
            return false;
        }
    }

    public abstract void onButtonPressed();

    public abstract void onButtonReleased();
}

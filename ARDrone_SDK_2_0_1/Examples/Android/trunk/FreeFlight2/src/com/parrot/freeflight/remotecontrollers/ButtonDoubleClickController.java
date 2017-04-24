package com.parrot.freeflight.remotecontrollers;

import android.view.KeyEvent;

public abstract class ButtonDoubleClickController
        implements ButtonController
{
    final static int MAX_DELAY = 500;
    final int buttonToTrack;
    public long lastPressedTime;

    public ButtonDoubleClickController(int theKeyCodeToTrack)
    {
        this.buttonToTrack = theKeyCodeToTrack;
        this.lastPressedTime = 0;
    }

    public final boolean onKeyEvent(KeyEvent theEvent)
    {
        final int keyCode = theEvent.getKeyCode();

        if (keyCode == buttonToTrack) {            
            if (theEvent.getAction() == KeyEvent.ACTION_DOWN) {
                final long currentTime = System.currentTimeMillis();
                if ((currentTime - this.lastPressedTime)< MAX_DELAY) {
                    this.lastPressedTime = 0;
                    onButtonDoubleClicked();                   
                }else{
                    this.lastPressedTime = currentTime;
                }
            }
            return true;
        } else {
            return false;
        }
    }

    public abstract void onButtonDoubleClicked();
}

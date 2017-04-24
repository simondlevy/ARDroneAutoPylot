package com.parrot.freeflight.remotecontrollers;

import java.util.HashMap;
import java.util.Map;

public class ControlButtons
{
    public final static String BUTTON_UP = "up";
    public final static String BUTTON_DOWN = "down";
    public final static String BUTTON_TURN_LEFT = "left";
    public final static String BUTTON_TURN_RIGHT = "right";
    public final static String BUTTON_ACCELEROMETR = "accelerometr";
    public final static String BUTTON_PITCH_LEFT = "pitch_left";
    public final static String BUTTON_PITCH_RIGHT = "pitch_right";
    public final static String BUTTON_ROLL_FORWARD = "roll_forward";
    public final static String BUTTON_ROLL_BACKWARD = "roll_backward";
    public final static String BUTTON_TAKE_OFF = "take_off";
    public final static String BUTTON_EMERGENCY = "emergency";
    public final static String BUTTON_CAMERA = "camera";
    public final static String BUTTON_SETTINGS = "menu";
    public final static String BUTTON_SALTO = "salto";
    public final static String BUTTON_RECORD = "record";
    public final static String BUTTON_PHOTO = "photo";
    
    private Map<String,Integer> controls;
    
    public ControlButtons()
    {
        controls = new HashMap<String, Integer>();
    }
    
    public void setUpControllButton(final String theKey,final Integer theButton)
    {
        this.controls.put(theKey, theButton);
    }
    
    /**
     * 
     * @param theKery
     * @return button code or -1 if no such code exists
     */
    public int getButtonCode(final String theKey)
    {
        final Integer button = this.controls.get(theKey);
        if(button != null)
        {
            return button;
        }else{
            return -1;
        }
    }
}

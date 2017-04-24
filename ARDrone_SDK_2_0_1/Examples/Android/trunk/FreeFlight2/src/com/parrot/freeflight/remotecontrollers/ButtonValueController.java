package com.parrot.freeflight.remotecontrollers;

import android.view.KeyEvent;

public abstract class ButtonValueController implements ButtonController
{
    private float MAX_VALUE = 1;
    private float MIN_VALUE = -1;
    private float ZERO_VALUE = 0;
   
    
    private float currentValue;
    
    private int incrementKeyCode;
    private int decrementKeyCode;
    
    public ButtonValueController(int theIncrementKeyCode,int theDecrementKeyCode)
    {
        this.incrementKeyCode = theIncrementKeyCode;
        this.decrementKeyCode = theDecrementKeyCode;
    }
    
    public final boolean onKeyEvent(KeyEvent theEvent)
    {
        final int keyCode = theEvent.getKeyCode();
        if(theEvent.getAction()==KeyEvent.ACTION_DOWN)
        {
            if(keyCode == incrementKeyCode)
            {
                applyValueUpdate(MAX_VALUE);
                return true;
            }else  if(keyCode == decrementKeyCode){
                applyValueUpdate(MIN_VALUE);
                return true;
            }
        } else if(theEvent.getAction()==KeyEvent.ACTION_UP)
        {            
            if(keyCode == incrementKeyCode)
            {
                applyValueUpdate(ZERO_VALUE);
                return true;
            }else  if(keyCode == decrementKeyCode){
                applyValueUpdate(ZERO_VALUE);
                return true;
            }
        }   
        
        return false;
        
    }
    
    private void applyValueUpdate(float delta)
    {
        float updatedValue =  delta;
       
        if(updatedValue != this.currentValue)
        {
            this.currentValue = updatedValue;
            onValueChanged(this.currentValue);
        }
    }   
    public abstract void onValueChanged(float theCurrentValue);
    
}

package com.parrot.freeflight.gestures;

import android.content.Context;
import android.view.GestureDetector;
import android.view.MotionEvent;

/**
 * EnhancedGestureDetector detects double tap gesture of second pointer when using multi touch in addition to
 * standard GestureDetecror gestures.
 */
public class EnhancedGestureDetector extends GestureDetector
{
    // This is minimal time interval between touches
    private static final int DOUBLE_TAP_TIMESTAMP_DELTA = 200;
    // This is minimal distance between two touches.
    private static final int COORDINATE_DELTA = 50;
    
    // Time stamp of previous touch
    private long timestampLast;
    // Coordinates of previous touch
    private float xLast;
    private float yLast;
    
    private OnDoubleTapListener listener;
   
    
    public EnhancedGestureDetector(Context context, OnGestureListener listener)
    {
        super(context, listener);
    }

    
    @Override
    public boolean onTouchEvent(MotionEvent ev)
    { 
        if (ev.getActionMasked() == MotionEvent.ACTION_POINTER_UP) {
            long currTimestamp = ev.getEventTime();
            
            if (ev.getPointerCount() > 1) {
                if (currTimestamp - timestampLast < DOUBLE_TAP_TIMESTAMP_DELTA &&
                        Math.abs(ev.getX(1) - xLast) < COORDINATE_DELTA &&
                        Math.abs(ev.getY(1) - yLast) < COORDINATE_DELTA ) 
                {
                    // Double tap detected. Calling listener.
                    if (listener != null) {
                        return listener.onDoubleTap(ev);
                    }
                }
            
                xLast = ev.getX(1);
                yLast = ev.getY(1);                    
                timestampLast = ev.getEventTime();
            }
        }
        
        return super.onTouchEvent(ev);
    }

    
    @Override
    public void setOnDoubleTapListener(OnDoubleTapListener onDoubleTapListener)
    {
        super.setOnDoubleTapListener(onDoubleTapListener);
        this.listener = onDoubleTapListener;
    }
}

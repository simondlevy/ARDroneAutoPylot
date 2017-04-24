/*
 * GLButton
 *
 *  Created on: Aug 23, 2011
 *      Author: Dmytro Baryskyy
 */


package com.parrot.freeflight.ui.hud;

import javax.microedition.khronos.opengles.GL10;

import android.content.res.Resources;
import android.graphics.Canvas;
import android.view.MotionEvent;
import android.view.View;
import android.view.View.OnClickListener;

import com.parrot.freeflight.ui.gl.GLSprite;

public class Button extends Sprite
{
	protected GLSprite spriteNormal;
	protected GLSprite spritePressed;

	protected boolean isPressed;
	private boolean isInitialized;
	
	private OnClickListener clickListener;
	private int pointerId; // Id of the pointer that has touched the control
	
	
	public Button(Resources resources, int normalBitmapId, int pressedBitmapId, Align align) 
	{
		super(align);
		
		spriteNormal = new GLSprite(resources, normalBitmapId);
		spritePressed = new GLSprite(resources, pressedBitmapId);
		isInitialized = false;
	}


	public void init(GL10 gl, int program) 
	{
		spriteNormal.init(gl, program);
		spritePressed.init(gl, program);

	}

	
	public void surfaceChanged(GL10 gl, int width, int height) 
	{
		spriteNormal.onSurfaceChanged(gl, width, height);
		spritePressed.onSurfaceChanged(gl, width, height);
		
		super.surfaceChanged(gl, width, height);
		
		isInitialized = true;
	}

	public void surfaceChanged(Canvas canvas) 
	{
		super.surfaceChanged(canvas);
		
		isInitialized = true;
	}

	
	public void draw(GL10 gl) 
	{
		if (bounds != null && visible) {
			if (isPressed) {
				spritePressed.onDraw(gl,  bounds.left, surfaceHeight - bounds.top - spritePressed.height);
			} else {
				spriteNormal.onDraw(gl,  bounds.left, surfaceHeight - bounds.top - spriteNormal.height);
			}
		}
	}

	
	public void draw(Canvas canvas) 
	{
		if (bounds != null) {
			if (isPressed) {
				spritePressed.onDraw(canvas, bounds.left, bounds.top);
			} else {
				spriteNormal.onDraw(canvas,  bounds.left, bounds.top);
			}
		}
	}

	
	@Override
    protected void onAlphaChanged(float newAlpha)
    {
	    spriteNormal.alpha = newAlpha;
        spritePressed.alpha = newAlpha;
    }


	public void setOnClickListener(OnClickListener listener)
	{
		this.clickListener = listener;
	}
	
	
	public void setImages(Resources resources, int normal, int pressed)
	{
		spriteNormal = new GLSprite(resources, normal);
		spritePressed = new GLSprite(resources, pressed);
		
		isInitialized = false;
	}
	
	
	public boolean onTouchEvent(View v, MotionEvent event) 
	{
		int action = event.getAction();
		int actionCode = action & MotionEvent.ACTION_MASK;
		int actionIndex = event.getActionIndex();

		switch (actionCode) {
		case MotionEvent.ACTION_DOWN:
		case MotionEvent.ACTION_POINTER_DOWN: {
			
		    for (int i=0; i<event.getPointerCount(); ++i) {
    			int x = (int)event.getX(i);
    			int y = (int)event.getY(i);
    			
    			if (bounds != null && bounds.contains(x, y)) {
    				if (enabled && visible) {
    				    pointerId = event.getPointerId(i);
    				    isPressed = true;
    				    
    				    return true;
    				} else if (!enabled && visible) {
    				    return true;
    				}
    			}
		    }
			
			break;
		}
		case MotionEvent.ACTION_UP:
		case MotionEvent.ACTION_POINTER_UP: 
			if (isPressed) {
			    for (int i=0; i<event.getPointerCount(); ++i) {
    				if (bounds != null && bounds.contains((int)event.getX(i), 
    													  (int)event.getY(i))
    													  && pointerId == event.getPointerId(i)) {
    					
    					if (clickListener != null && enabled && visible) {
    						clickListener.onClick(null);
    					}
    					
    					isPressed = false;
    					pointerId = 0;
    					return true;
    				}
			    }
			}
			
			break;
			
		case MotionEvent.ACTION_MOVE:
		    if (isPressed) {
		        for (int i=0; i<event.getPointerCount(); ++i) {
		            if (pointerId == event.getPointerId(i)) {
        		        int x = (int) event.getX(actionIndex);
        		        int y = (int) event.getY(actionIndex);
        		        
        		        if (!bounds.contains(x, y)) {
        		            isPressed = false;
        		            pointerId = 0;
        		        }
		            }
		        }
		    }
		    break;
		}
		
		return false;
	}


	public boolean isInitialized()
	{
		return isInitialized;		
	}	

	
	@Override
	public void setViewAndProjectionMatrices(float[] vMatrix, float[] projMatrix) {
		spriteNormal.setViewAndProjectionMatrices(vMatrix, projMatrix);
		spritePressed.setViewAndProjectionMatrices(vMatrix, projMatrix);
	}


	@Override
	public int getWidth()
	{
		return spriteNormal.width;
	}


	@Override
	public int getHeight() 
	{
		return spriteNormal.height;
	}


    @Override
    public void freeResources()
    {
        spriteNormal.freeResources();
        spritePressed.freeResources();
    }
}

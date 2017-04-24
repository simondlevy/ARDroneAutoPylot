package com.parrot.freeflight.ui.hud;

import javax.microedition.khronos.opengles.GL10;

import android.graphics.Canvas;
import android.graphics.Rect;
import android.view.MotionEvent;
import android.view.View;

public abstract class Sprite 
{
	public enum Align {
		NO_ALIGN,
		CENTER,
		TOP_CENTER,
		BOTTOM_CENTER,
		TOP_RIGHT,
		TOP_LEFT,
		BOTTOM_RIGHT,
		BOTTOM_LEFT
	}

	protected Align alignment;
	protected Rect bounds;
    protected Rect margin;
    
	protected int surfaceWidth;
	protected int surfaceHeight;
	
	protected boolean alphaEnabled;	
	protected boolean enabled;
	protected boolean visible;
	
	private float prevAlpha;
	private float alpha;
	
	public Sprite(Align alignment)
	{
		this.alignment = alignment;
		alphaEnabled = true;
		visible = true;
		alpha = 1.0f;
		enabled = true;
		bounds = new Rect();
		margin = new Rect();
		
	}
	
	public void surfaceChanged(GL10 gl, int width, int height)
	{
		surfaceWidth = width;
		surfaceHeight = height;
		
		layout(width, height);
	}
	
	
	public void surfaceChanged(Canvas canvas)
	{
		surfaceWidth = canvas.getWidth();
		surfaceHeight = canvas.getHeight();
		
		layout(surfaceWidth, surfaceHeight);
	}
	
	
	public boolean processTouch(View v, MotionEvent event)
	{
		return onTouchEvent(v, event);
	}
	
	
	protected void layout(int width, int height) 
	{
		switch (alignment) {
		case TOP_CENTER:
			bounds.set((width - getWidth()) / 2, margin.top, ((width -getWidth()) / 2) + getWidth(), getHeight() + margin.top);
			break;
		case BOTTOM_CENTER:
			bounds.set((width - getWidth()) / 2, height - getHeight(), ((width - getWidth()) / 2) + getWidth(), height);
			break;
		case TOP_RIGHT:
			bounds.set(width - getWidth() - margin.right, margin.top, width - margin.right, margin.top + getHeight());
			break;
		case TOP_LEFT:
			bounds.set(margin.left, margin.top, margin.left + getWidth(), margin.top + getHeight());
			break;
		case BOTTOM_LEFT:
			bounds.set(margin.left, height - getHeight() - margin.bottom, getWidth() + margin.left, height - margin.bottom);
			break;
		case BOTTOM_RIGHT:
		    bounds.set(width - getWidth() - margin.right, height - getHeight() - margin.bottom, width - margin.right, height - margin.bottom);
		    break;
		default:
		    // Left unimplemented
		}
	}

	
	public void setMargin(int top, int right, int bottom, int left)
	{
	    margin.set(left, top, right, bottom);
	}
	
	
	public void setAlphaEnabled(boolean enabled)
	{
		this.alphaEnabled = enabled;
	}
	
	
	final public void setAlpha(float alpha)
    {
	    if (!alphaEnabled) {
	        return;
	    }
	    
	    boolean alphaChanged = alpha != this.alpha;
        this.alpha = alpha;
        
        if (alphaChanged && alphaEnabled) {
            onAlphaChanged(this.alpha);
        }
    }
	
	
    final public float getAlpha()
    {
        return alpha;
    }
    
    
    public void setVisible(boolean visible)
    {
        this.visible = visible;
    }
    
    
    public boolean isVisible()
    {
        return this.visible;
    }
	
    
    protected void onAlphaChanged(float newAlpha)
    {
        // Left unimplemented
    }
    
    
	public void setEnabled(boolean enabled)
	{
	    if (this.enabled != enabled) {
	        this.enabled = enabled;
	        
     		if (enabled) {
    			if (prevAlpha != 0) {
    				setAlpha(prevAlpha);
    			} else {
    				setAlpha(1.0f);
    			}
    		} else {
    			prevAlpha = getAlpha();
    			setAlpha(0.5f);
    		}
	    }   
	}
	
	
	public boolean isEnabled()
	{
	    return enabled;
	}

	   
	public abstract void init(GL10 gl, int program);
    public abstract void draw(GL10 gl);
    public abstract void draw(Canvas canvas);
    public abstract boolean onTouchEvent(View v, MotionEvent event);
    public abstract boolean isInitialized();
    public abstract void setViewAndProjectionMatrices(float[] vMatrix, float[] projMatrix);
    public abstract int getWidth();
    public abstract int getHeight();
    public abstract void freeResources();
}

/*
 * JoystickBase
 *
 *  Created on: May 26, 2011
 *      Author: Dmytro Baryskyy
 */

package com.parrot.freeflight.ui.hud;

import javax.microedition.khronos.opengles.GL10;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Rect;
import android.graphics.RectF;
import android.view.MotionEvent;
import android.view.View;

import com.parrot.freeflight.R;
import com.parrot.freeflight.ui.gl.GLSprite;

public abstract class JoystickBase extends Sprite
{
	private static final String TAG = "Joystick";
	
    private static final double CONTROL_RATIO = 1 / 3;

    private float controlRatio;
    
	protected boolean isPressed;
	
	private float baseX;
	private float baseY;
	
	protected float centerX;
	protected float centerY;
	
	private float thumbCenterX;
	private float thumbCenterY;
	
	private float opacity;
	
	protected RectF activationRect;
	
	protected GLSprite bg;
	protected GLSprite thumbNormal;
	protected GLSprite thumbAbsolute;
	
	protected JoystickListener analogueListener;

	protected boolean inverseY;
	protected int fingerId;

	private boolean isInitialized;
	protected boolean absolute;
	
	public JoystickBase(final Context context, Align align, boolean absolute)
	{
		super(align);
		
		opacity = 1.f;
		isPressed = false;
		isInitialized = false;
		this.absolute = absolute;
		
		centerX = 0;
		centerY = 0;

		int bgResId = getBackgroundDrawableId();
		int thumbResId = getTumbDrawableId();
		int thumbAbsoluteId = getThumbAbsoluteDrawableId();
		
		if (bgResId != 0) {
			bg = new GLSprite(context.getResources(), bgResId);
		}
		
		if (thumbResId != 0) {
			thumbNormal = new GLSprite(context.getResources(), thumbResId);
		}
		
		if (thumbAbsoluteId != 0) {
		    thumbAbsolute = new GLSprite(context.getResources(), thumbAbsoluteId);
		}
		
		alignment = align;
		fingerId = -1;
		
        controlRatio = (float) (0.5 - (CONTROL_RATIO / 2.0));
	}
	


    public void surfaceChanged(GL10 gl, int width, int height)
	{	
		if (bg != null) {
			bg.onSurfaceChanged(gl, width, height);
		}
		
		if (thumbNormal != null) {
			thumbNormal.onSurfaceChanged(gl, width, height);
		}
		
		if (thumbAbsolute != null) {
		    thumbAbsolute.onSurfaceChanged(gl, width, height);
		}

		super.surfaceChanged(gl, width, height);
	
		updateActivatonRegion(width, height);
		
		isInitialized = true;
	}
	
	

	public void surfaceChanged(Canvas canvas) 
	{
		super.surfaceChanged(canvas);
	
		updateActivatonRegion(canvas.getWidth(), canvas.getHeight());
		
		isInitialized = true;
	}


	private void updateActivatonRegion(int width, int height) 
	{
		switch (alignment) {
		case BOTTOM_LEFT:
			setActivationRect(new Rect(0,0, width / 2, height));
			break;
		case BOTTOM_RIGHT:
			setActivationRect(new Rect(width / 2, 0, width, height));
			break;
		default:
		    //not implemented
		}
	}
	
	
	public void draw(Canvas canvas)
	{
		updateControlOpacity();	
		
		if (bg != null)
			bg.onDraw(canvas, centerX-(bg.width >> 1) - margin.left, inverseY(centerY - (bg.height >> 1)));
		
		if (thumbNormal != null)
			thumbNormal.onDraw(canvas, thumbCenterX-(thumbNormal.width >> 1), inverseY(thumbCenterY - (thumbNormal.height >> 1)));
	}
	
	
    public void draw(GL10 gl)
    {
        updateControlOpacity();

        if (bg != null)
            bg.onDraw(gl, centerX - (bg.width >> 1), (centerY - (bg.height >> 1)));

        if (absolute) {
            if (thumbAbsolute != null) {
                thumbAbsolute.onDraw(gl, thumbCenterX - (thumbNormal.width >> 1),
                        (thumbCenterY - (thumbNormal.height >> 1)));
            }
        } else {
            if (thumbNormal != null) {
                thumbNormal.onDraw(gl, thumbCenterX - (thumbNormal.width >> 1),
                        (thumbCenterY - (thumbNormal.height >> 1)));
            }
        }
    }

	
	public void setActivationRect(Rect rect)
	{
		this.activationRect = new RectF(rect);
	
		switch (alignment) {
		case BOTTOM_LEFT:
			baseX = activationRect.left + (bg.width / 2.0f) + margin.left;
			baseY = activationRect.bottom - (bg.height/2.0f) - margin.bottom;
			break;
		case BOTTOM_RIGHT:
			baseX = activationRect.right - (bg.width / 2.0f) - margin.right;
			baseY = activationRect.bottom - (bg.height/2.0f) - margin.bottom;
			break;
		default:
			// Not implemented yet    
		}
		
		moveToBase(activationRect);
	}


	protected void moveToBase(RectF rect) {
		moveTo(baseX, baseY);
		
        if (analogueListener != null) {
            analogueListener.onChanged(this, 0, 0);
            analogueListener.onReleased(this);
        }
	}
	
	
	public void moveTo(float x, float y)
	{
		this.centerX = x;
		this.centerY = inverseY(y);

		moveThumbTo(x, inverseY(y));
	}
	
	
	public void moveThumbTo(float x, float y)
	{
		double dx = x - centerX;
		double dy = y - centerY;
		
		double distance = Math.sqrt(dx*dx + dy*dy);
		double angle = Math.atan2(dy, dx);
		
		float joy_radius = bg.width / 2.0f - thumbNormal.width * 0.33f / 2;
		
		if (distance  > joy_radius) {
			dx = Math.cos(angle) * joy_radius;
			dy = Math.sin(angle) * joy_radius;
			
			this.thumbCenterX = centerX + (float) dx;
			this.thumbCenterY = centerY + (float) dy;
		} else {
			this.thumbCenterX = x;
			this.thumbCenterY = y;
		}
	}
	
	
	public void init(GL10 gl, int program) {
		bg.init(gl, program);
		thumbNormal.init(gl, program);
		thumbAbsolute.init(gl, program);
	}
	
	
	public boolean onTouchEvent(View v, MotionEvent event) 
	{
		if (activationRect == null)
			return false;
		
		int action = event.getAction();
		int actionCode = action & MotionEvent.ACTION_MASK;
		int pointerIdx = action >> MotionEvent.ACTION_POINTER_INDEX_SHIFT;

		switch (actionCode) {
			case MotionEvent.ACTION_POINTER_DOWN:
			case MotionEvent.ACTION_DOWN:
				
				if (fingerId == -1 && activationRect.contains(event.getX(pointerIdx), event.getY(pointerIdx))) {
					fingerId = event.getPointerId(pointerIdx);
					isPressed = true;
					onActionDown(event.getX(pointerIdx), event.getY(pointerIdx));
					return true;
				}

				return false;
			case MotionEvent.ACTION_POINTER_UP:
			case MotionEvent.ACTION_UP:
			{	
				if (fingerId == -1)
					return false;
				
				if (event.getPointerId(pointerIdx) != fingerId)
					return false;
						
				fingerId = -1;
				onActionUp(event.getX(pointerIdx),  event.getY(pointerIdx));
				isPressed = false;
				return true;
			}
			case MotionEvent.ACTION_MOVE: 
			{
				if (fingerId == -1)
					return false;
				
				for (int i=0; i<event.getPointerCount(); ++i)  {
					if (event.getPointerId(i) == fingerId) {
						onActionMove(event.getX(i), event.getY(i));		
						return true;
					}
				}

				return false;
			}
			default:
				return false;
		}
	}
	
	
	public void setOnAnalogueChangedListener(JoystickListener listener)
	{
		this.analogueListener = listener;
	}
	
	
	public void setInverseYWhenDraw(boolean inverse)
	{
		inverseY = inverse;
	}
	

    @Override
    protected void onAlphaChanged(float newAlpha)
    {
        opacity = newAlpha;
    }


    protected int getBackgroundDrawableId()
    {
        return R.drawable.joystick_halo;
    }



    protected int getTumbDrawableId()
    {
        return R.drawable.joystick_manuel;
    }

        
    private int getThumbAbsoluteDrawableId()
    {
        return R.drawable.joystick_absolut_control;
    }


    protected void onActionDown(float x, float y)
    {
        isPressed = true;

        moveTo(x, y);

        if (analogueListener != null) {
            analogueListener.onChanged(this, 0, 0);
            analogueListener.onPressed(this);
        }
    }



    protected void onActionMove(float x, float y)
    {
        float radius = bg.width / 2.0f - thumbNormal.width * 0.33f / 2;
        moveThumbTo(x, inverseY(y));

        if (analogueListener != null) {
            float xvalue = 0;
            float yvalue = 0;

            if ((centerX - x) > (radius - (controlRatio * bg.width) / 2)) {
                xvalue = getXValue(centerX, x, radius);
            } else if ((x - centerX) > (radius - (controlRatio * bg.width) / 2)) {
                xvalue = getXValue(centerX, x, radius);
            }

            if ((centerY - inverseY(y)) > (radius - (controlRatio * bg.width) / 2)) {
                yvalue = getYValue(centerY, y, radius);
            } else if ((inverseY(y) - centerY) > (radius - (controlRatio * bg.width) / 2)) {
                yvalue = getYValue(centerY, y, radius);
            }

            analogueListener.onChanged(this, xvalue, yvalue);
        }
    }



    protected void onActionUp(float x, float y)
    {
        isPressed = false;
        moveToBase(activationRect);
    }
    


	protected float inverseY(float y) 
	{
		if (inverseY) {
			return surfaceHeight - y;
		} else {
			return y;
		}
	}
	

	private void updateControlOpacity() 
	{
		if (isPressed) {
			if (bg != null)
				bg.alpha = 1.0f;
			
			if (bg != null)
				thumbNormal.alpha = 1.0f;
			
			if (thumbAbsolute != null) {
			    thumbAbsolute.alpha = 1.0f;
			}
		} else {
			
			if (bg != null)
				bg.alpha = opacity;
			
			if (thumbNormal != null)
				thumbNormal.alpha = opacity;
			
			if (thumbAbsolute != null) {
			    thumbAbsolute.alpha = opacity;
			}
		}
	}


	public void setAlign(Align alignment) 
	{
		this.alignment = alignment;
	}
	

	public boolean isInitialized() 
	{
		return isInitialized;
	}
	

	@Override
	public void setViewAndProjectionMatrices(float[] vMatrix, float[] projMatrix) {
		bg.setViewAndProjectionMatrices(vMatrix, projMatrix);
		thumbNormal.setViewAndProjectionMatrices(vMatrix, projMatrix);	
		thumbAbsolute.setViewAndProjectionMatrices(vMatrix, projMatrix);
	}


	@Override
	public int getWidth() 
	{
		return bg.width;
	}


	@Override
	public int getHeight() 
	{
		return bg.height;
	}
	
	
	public boolean isAbsoluteControl()
	{
	    return absolute;
	}

	
    @Override
    public void freeResources()
    {
       bg.freeResources();
       thumbNormal.freeResources();
       thumbAbsolute.freeResources();
    }
    


    private float getXValue(float centerX, float x, float radius)
    {
        return -1 * ((centerX - x) - (radius - (controlRatio * (radius * 2)))) / ((controlRatio * (radius * 2)));
    }


    private float getYValue(float centerY, float y, float radius)
    {
        return -1 * ((centerY - inverseY(y)) - (radius - (controlRatio * (radius * 2))))
                / ((controlRatio * (radius * 2)));
    }


    public void setAbsolute(boolean b)
    {
       this.absolute = b;      
    }
}

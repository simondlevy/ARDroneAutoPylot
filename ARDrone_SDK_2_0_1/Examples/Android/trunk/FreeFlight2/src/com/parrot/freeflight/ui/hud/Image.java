package com.parrot.freeflight.ui.hud;

import javax.microedition.khronos.opengles.GL10;

import android.content.res.Resources;
import android.graphics.Canvas;
import android.graphics.Rect;
import android.view.MotionEvent;
import android.view.View;

import com.parrot.freeflight.ui.gl.GLSprite;

public class Image extends Sprite 
{
	public enum SizeParams {
		NONE,
		FILL_SCREEN
	}
	
	private GLSprite sprite;
	private SizeParams widthParam;
	private SizeParams heightParam;
	
	private boolean isInitialized;
	
   
	public Image(Resources resources, int resId, Align align)
	{
		super(align);
		
		widthParam = SizeParams.NONE;
		heightParam = SizeParams.NONE;
		
		isInitialized = false;
		sprite = new GLSprite(resources, resId);	
	}
	
	
	@Override
	public void init(GL10 gl, int program) 
	{
		sprite.init(gl, program);
		isInitialized = true;
	}

	
	@Override
	public void surfaceChanged(GL10 gl, int width, int height) 
	{
		sprite.onSurfaceChanged(gl, width, height);
		
		if (widthParam == SizeParams.FILL_SCREEN) {
			sprite.setSize(width, sprite.height);
		}
		
		super.surfaceChanged(gl, width, height);
	}

	
	@Override
	public void surfaceChanged(Canvas canvas)
	{
		super.surfaceChanged(canvas);
	}

	
	@Override
	public void draw(GL10 gl) 
	{
		sprite.onDraw(gl, bounds.left, surfaceHeight - bounds.top - sprite.height);
	}

	
	@Override
	public void draw(Canvas canvas)
	{
		sprite.onDraw(canvas, bounds.left, bounds.top);
	}
	

	@Override
	public boolean onTouchEvent(View v, MotionEvent event) 
	{
		return false;
	}

	
	@Override
    protected void onAlphaChanged(float newAlpha)
    {
	    sprite.setAlpha(newAlpha);
    }


	@Override
	public boolean isInitialized() 
	{
		return isInitialized;
	}

	
	@Override
	public void setViewAndProjectionMatrices(float[] vMatrix, float[] projMatrix) 
	{
		sprite.setViewAndProjectionMatrices(vMatrix, projMatrix);
	}

	
	public void setBounds(Rect rect)
	{
		this.bounds = rect;
	}

	
	public void setPosition(int x, int y) 
	{
		bounds.offsetTo(x, y);
	}

	
	@Override
	public int getWidth() 
	{
		return sprite.width;
	}

	@Override
	public int getHeight() 
	{
		return sprite.height;
	}
	

	public void setSizeParams(SizeParams width, SizeParams height) 
	{
		widthParam = width;
		heightParam = height;
	}

	
    @Override
    public void freeResources()
    {
        sprite.freeResources();
    }
}

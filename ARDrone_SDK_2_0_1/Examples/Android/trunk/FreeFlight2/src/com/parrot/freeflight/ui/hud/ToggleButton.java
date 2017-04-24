package com.parrot.freeflight.ui.hud;

import javax.microedition.khronos.opengles.GL10;

import android.content.res.Resources;
import android.graphics.Canvas;

import com.parrot.freeflight.ui.gl.GLSprite;

public class ToggleButton extends Button
{
	private boolean checked;
	private float lightAlpha;
	private long prevNano;
	private int alphaCoef;
	
	private GLSprite spriteGlow;
	private GLSprite spriteCheckedNormal;
	private GLSprite spriteCheckedPressed;
	
	public ToggleButton(Resources resources, int normalBitmapId,
			int pressedBitmapId, int checkedNormalBitmapId, int checkedPressedBitmapId, 
			int glowBitmapId, Align align) 
	{
		super(resources, normalBitmapId, pressedBitmapId, align);
		
		spriteGlow = new GLSprite(resources, glowBitmapId);
		spriteCheckedNormal = new GLSprite(resources, checkedNormalBitmapId);
		spriteCheckedPressed = new GLSprite(resources, checkedPressedBitmapId);
		
		lightAlpha = 1.0f;
		alphaCoef = -1;
		checked = false;
	}

	
	@Override
	public void init(GL10 gl, int program) 
	{
		super.init(gl, program);
		spriteGlow.init(gl, program);
		spriteCheckedNormal.init(gl, program);
		spriteCheckedPressed.init(gl, program);
	}


	@Override
	public void surfaceChanged(GL10 gl, int width, int height) 
	{
		super.surfaceChanged(gl, width, height);
		spriteGlow.onSurfaceChanged(gl, width, height);
		spriteCheckedNormal.onSurfaceChanged(gl, width, height);
        spriteCheckedPressed.onSurfaceChanged(gl, width, height);
	}


	@Override
	public void draw(GL10 gl) 
	{
		if (bounds != null) {
			if (checked) {
				long nano = System.nanoTime();
				if (nano - prevNano > 100) {
					prevNano = nano;
					
					lightAlpha += 0.05 * alphaCoef;
		
					if (lightAlpha < 0) {
						alphaCoef = 1;
					} else if (lightAlpha > 1) {
						alphaCoef = -1;
					}
					
					spriteGlow.setAlpha(lightAlpha);
				}

				if (isPressed) {
				    spriteCheckedPressed.onDraw(gl,  bounds.left, surfaceHeight - bounds.top - spritePressed.height);
				} else {
				    spriteCheckedNormal.onDraw(gl,  bounds.left, surfaceHeight - bounds.top - spritePressed.height);
				}
				
				spriteGlow.onDraw(gl,  bounds.left, surfaceHeight - bounds.top - spriteGlow.height);
			} else {
			    if (isPressed) {
			        spritePressed.onDraw(gl,  bounds.left, surfaceHeight - bounds.top - spriteNormal.height);
			    } else {
			        spriteNormal.onDraw(gl,  bounds.left, surfaceHeight - bounds.top - spriteNormal.height);
			    }
			}
		}
	}

	
	@Override
	public void draw(Canvas canvas) {
		if (bounds != null) {
			if (checked) {
				spritePressed.onDraw(canvas, bounds.left, bounds.top);
			} else {
				spriteNormal.onDraw(canvas,  bounds.left, bounds.top);
			}
		}
	}
	

    public void setChecked(boolean checked)
	{
		this.checked = checked;
	}


	@Override
	public void setViewAndProjectionMatrices(float[] vMatrix, float[] projMatrix)
	{
		super.setViewAndProjectionMatrices(vMatrix, projMatrix);
		spriteGlow.setViewAndProjectionMatrices(vMatrix, projMatrix);
		spriteCheckedNormal.setViewAndProjectionMatrices(vMatrix, projMatrix);
		spriteCheckedPressed.setViewAndProjectionMatrices(vMatrix, projMatrix);
	}
}

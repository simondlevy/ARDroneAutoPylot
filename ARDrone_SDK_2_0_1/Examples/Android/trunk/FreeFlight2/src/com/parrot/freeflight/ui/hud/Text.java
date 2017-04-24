package com.parrot.freeflight.ui.hud;

import javax.microedition.khronos.opengles.GL10;

import android.content.Context;
import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.view.MotionEvent;
import android.view.View;

import com.parrot.freeflight.ui.gl.GLSprite;

public class Text extends Sprite{

	public static final int VISIBLE = 1;
	public static final int INVISIBLE = 0;
	
	private GLSprite sprite;
	private String text;
	private Paint paint;
	private int visibility;
	
	private boolean updateTexture;
	private boolean blink;
	private long prevNano;
	
	private Resources res;
	
	public Text(Context context, String text, Align alignment) {
		super(alignment);	
		res = context.getResources();
		this.paint = new Paint();

		Resources res = context.getResources();
		paint.setColor(res.getColor(android.R.color.primary_text_dark));
		paint.setTextSize(24);
		paint.setAntiAlias(true);
		paint.setSubpixelText(true);
		
		this.text = text;
		
		initSprite();
		
		updateTexture = false;
		visibility = VISIBLE;
	}
	
	
	private void initSprite()
	{
		Bitmap bitmap = createBitmapToRender();
		sprite = new GLSprite(res, bitmap);
		bitmap.recycle();
	}


	private Bitmap createBitmapToRender() {
		float width = 1;
		float height = 1;
		
		if (text.length() > 0) {  
			width = paint.measureText(text);
			height = paint.getTextSize();
		}
		
		Bitmap bitmap = Bitmap.createBitmap(Math.round(width), Math.round(height), Bitmap.Config.ARGB_4444);
		bitmap.eraseColor(0x00000000);
		bitmap.setDensity(res.getDisplayMetrics().densityDpi);
		Canvas canvas = new Canvas(bitmap);
		canvas.drawText(text, 0, height - paint.getFontMetrics().bottom, paint);
		return bitmap;
	}

	@Override
	public void init(GL10 gl, int program) {
		sprite.init(gl, program);
	}

	@Override
	public void draw(GL10 gl) 
	{	
		if (updateTexture) {
			Bitmap bitmap = createBitmapToRender();
			sprite.updateTexture(res, bitmap);
			layout(surfaceWidth, surfaceHeight);
			
			updateTexture = false;
		}
		
		if (blink) {
			long nano = System.currentTimeMillis();
			if (nano - prevNano > 500) {
				prevNano = nano;
				
				if (sprite.alpha >= 1.0f) {
					sprite.setAlpha(0.0f);
				} else {
					sprite.setAlpha(1.0f);
				}
			}
		}
		
		if (visibility == VISIBLE) {
			sprite.onDraw(gl, bounds.left, surfaceHeight - bounds.top - sprite.height);
		}
	}

	@Override
	public void draw(Canvas canvas) {
		// TODO Auto-generated method stub
		
	}

	@Override
	public boolean onTouchEvent(View v, MotionEvent event) 
	{
		return false;
	}

	
	public void onAlphaChanged(float newAlpha)
	{
	    sprite.setAlpha(newAlpha);
	}
	
	
	@Override
	public boolean isInitialized() 
	{
		return sprite.isReadyToDraw();
	}

	
	@Override
	public void setViewAndProjectionMatrices(float[] vMatrix, float[] projMatrix) 
	{
		sprite.setViewAndProjectionMatrices(vMatrix, projMatrix);	
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
	
	
	public void setTextSize(int size)
	{
		if (paint.getTextSize() != size) {
			paint.setTextSize(size);
			invalidate();
		}
	}
	
	
	public void setTextColor(int color)
	{
		if (color != paint.getColor()) {
			paint.setColor(color);
			invalidate();
		}
	}
	

	public void setText(String string) 
	{
		if (!this.text.equals(string)) {
			this.text = string;
			invalidate();
		}
	}
	
	
	public void setBold(boolean bold)
	{
		if (bold) {
			paint.setTypeface(Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD));
		} else {
			paint.setTypeface(Typeface.create(Typeface.SANS_SERIF, Typeface.NORMAL));
		}
	}


	public void setVisibility(int visibility) {
		this.visibility = visibility;	
	}
	
	
	private void invalidate()
	{
		updateTexture = true;
	}


	public void blink(boolean b) 
	{	
		this.blink = b;
	}


	public void setTypeface(Typeface tf) 
	{
		paint.setTypeface(tf);
		invalidate();
	}

	
    @Override
    public void freeResources()
    {
        sprite.freeResources();
    }

}

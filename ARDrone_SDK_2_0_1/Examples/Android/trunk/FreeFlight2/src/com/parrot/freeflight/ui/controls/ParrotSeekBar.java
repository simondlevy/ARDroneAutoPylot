package com.parrot.freeflight.ui.controls;

import android.content.Context;
import android.content.res.Resources;
import android.content.res.TypedArray;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Typeface;
import android.util.AttributeSet;
import android.view.Gravity;
import android.widget.SeekBar;
import android.widget.TableLayout.LayoutParams;
import android.widget.TextView;

import com.parrot.freeflight.R;

public class ParrotSeekBar extends SeekBar {
	
	private TextView lowerBoundView;
	private TextView upperBoundView;
	private int textColor = Color.WHITE;	
	
	public ParrotSeekBar(Context context, AttributeSet attrs)
	{
		super (context, attrs);
		
		setThumbOffset(2);
		
		lowerBoundView = new TextView(context, attrs);
		lowerBoundView.setLayoutParams(new LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.MATCH_PARENT));
		lowerBoundView.setGravity(Gravity.LEFT);
		
		upperBoundView = new TextView(context, attrs);
		upperBoundView.setLayoutParams(new LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.MATCH_PARENT));
		upperBoundView.setGravity(Gravity.RIGHT);
	
		initControl(context, attrs);
		
		updateTextColor();
	}
	
	public ParrotSeekBar(Context context, AttributeSet attrs, int defStyle) 
	{
		super(context, attrs, defStyle);
		
		setThumbOffset(2);
			
		lowerBoundView = new TextView(context, attrs, defStyle);
		lowerBoundView.setLayoutParams(new LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.MATCH_PARENT));
		lowerBoundView.setGravity(Gravity.LEFT);
		
		upperBoundView = new TextView(context, attrs, defStyle);
		upperBoundView.setLayoutParams(new LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.MATCH_PARENT));
		upperBoundView.setGravity(Gravity.RIGHT);
		
		initControl(context, attrs);
		
		updateTextColor();
	}


	private void initControl(Context context, AttributeSet attrs) 
	{		
		Resources res = context.getResources();
		
		float topPadding = res.getDimension(R.dimen.settings_seek_text_padding_top);
		
		TypedArray a = context.obtainStyledAttributes(attrs, R.styleable.ParrotSeekBar);
		
		float lowerBoundLeft = a.getDimension(R.styleable.ParrotSeekBar_lowerValuePaddingLeft, 0);
		float upperBoundRight = a.getDimension(R.styleable.ParrotSeekBar_upperValuePaddingRight, 0);
		topPadding = a.getDimension(R.styleable.ParrotSeekBar_textPaddingTop, topPadding);
		String upperBoundText = a.getString(R.styleable.ParrotSeekBar_upperBoundText);
		String lowerBoundText = a.getString(R.styleable.ParrotSeekBar_lowerBoundText);
		
		lowerBoundView.setText(lowerBoundText);
		upperBoundView.setText(upperBoundText);
		lowerBoundView.setPadding((int)lowerBoundLeft, (int)topPadding, 0, 0);
		upperBoundView.setPadding(0, (int)topPadding, (int)upperBoundRight, 0);
		
		a.recycle();
	}
	
	
	
	@Override
	protected synchronized void onDraw(Canvas canvas) 
	{
		super.onDraw(canvas);
		lowerBoundView.draw(canvas);
		upperBoundView.draw(canvas);
	}

	@Override
	public void invalidate()
	{
		updateTextColor();
		super.invalidate();
	}

	
	private void updateTextColor() 
	{
		float progr = (float)getProgress() / (float)getMax();
		
		if (lowerBoundView != null) {
			if (progr < 0.05) {		
				lowerBoundView.setTextColor(Color.BLACK);
			} else {
				lowerBoundView.setTextColor(textColor);
			}
		}
		
		if (upperBoundView != null) {
			if (progr > 0.93) {
				upperBoundView.setTextColor(Color.BLACK);
			} else {
				upperBoundView.setTextColor(textColor);
			}
		}
	}

	@Override
	protected synchronized void onMeasure(int widthMeasureSpec,
			int heightMeasureSpec) {
		lowerBoundView.measure(widthMeasureSpec, heightMeasureSpec);
		upperBoundView.measure(widthMeasureSpec, heightMeasureSpec);
		super.onMeasure(widthMeasureSpec, heightMeasureSpec);
	}

	@Override
	protected void onLayout(boolean changed, int left, int top, int right,
			int bottom) 
	{
		super.onLayout(changed, left, top, right, bottom);
		
		lowerBoundView.layout(left, top, right, bottom);
		upperBoundView.layout(left, top, right, bottom);
	}
	
	public void setTypeface(Typeface tf)
	{
		lowerBoundView.setTypeface(tf);
		upperBoundView.setTypeface(tf);
	}
}

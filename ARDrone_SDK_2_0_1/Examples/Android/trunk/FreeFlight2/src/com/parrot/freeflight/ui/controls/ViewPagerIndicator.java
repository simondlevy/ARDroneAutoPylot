package com.parrot.freeflight.ui.controls;

import android.content.Context;
import android.content.res.Resources;
import android.content.res.TypedArray;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.support.v4.view.ViewPager;
import android.support.v4.view.ViewPager.OnPageChangeListener;
import android.util.AttributeSet;
import android.view.View;

import com.parrot.freeflight.R;

public class ViewPagerIndicator extends View 
implements OnPageChangeListener
{
	private Paint pageIndicatorPaint;
	private Paint pageIndicatorCurrentPaint;
	private float radius;
	private float gap;
	private int currentPage;
	private int pageCount;
	
	private int dy;
	private int startX;

	private OnPageChangeListener viewPagerListener;
	
	public ViewPagerIndicator(Context context, AttributeSet attrs) 
	{
		this(context, attrs, R.attr.viewPagerIndicatorStyle);	
	}

	
	public ViewPagerIndicator(Context context) 
	{
		this(context, null);
    }

	
	public ViewPagerIndicator(Context context, AttributeSet attrs, int defStyle) 
	{
		super(context, attrs, defStyle);	
		
		currentPage = 1;
		pageCount = 5;
		
		Resources res = context.getResources();
		
		radius = res.getDimension(R.dimen.default_circle_indicator_radius);
		gap = res.getDimension(R.dimen.default_circle_indicator_gap);
		int currentPageColor = res.getColor(R.color.default_circle_indicator_active_color);
		int pageColor = res.getColor(R.color.default_circle_indicator_color);
		
		TypedArray a = context.obtainStyledAttributes(attrs, R.styleable.ViewPagerIndicator, defStyle, R.style.ViewPagerIndicatorStyle);
		
		radius = a.getDimension(R.styleable.ViewPagerIndicator_radius, radius);
		gap = a.getDimension(R.styleable.ViewPagerIndicator_gap, gap);
		pageColor = a.getColor(R.styleable.ViewPagerIndicator_color, pageColor);
		currentPageColor = a.getColor(R.styleable.ViewPagerIndicator_activeColor, currentPageColor);
		
		a.recycle();
		
		pageIndicatorPaint = new Paint();
		pageIndicatorPaint.setAntiAlias(true);
		pageIndicatorPaint.setColor(pageColor);
		pageIndicatorPaint.setStyle(Paint.Style.FILL);
		
		pageIndicatorCurrentPaint = new Paint(pageIndicatorPaint);
		pageIndicatorCurrentPaint.setColor(currentPageColor);
	}

	
	public void setViewPager(ViewPager viewPager)
	{
		if (viewPager.getAdapter() == null) {
			throw new IllegalStateException("View pager should be bind to adapter first.");
		}
		
		pageCount = viewPager.getAdapter().getCount();		
		currentPage = viewPager.getCurrentItem();
		viewPager.setOnPageChangeListener(this);
		
		invalidate();
	}
	
	
	public void setOnPageChangeListener(OnPageChangeListener listener)
	{
		this.viewPagerListener = listener;
	}
	
	
	@Override
	protected void onDraw(Canvas canvas) 
	{
		super.onDraw(canvas);
			
		for (int i=0; i<pageCount; ++i) {
			int dx = startX + (int)(radius + getPaddingLeft() + (i * radius * 3) + (i * gap));
			
			if (currentPage == i) {
				canvas.drawCircle(dx, dy, radius, pageIndicatorCurrentPaint);
			} else {
				canvas.drawCircle(dx, dy, radius, pageIndicatorPaint);
			}
		}
	}
	
	
	@Override
	protected void onLayout(boolean changed, int left, int top, int right,
			int bottom) 
	{
		super.onLayout(changed, left, top, right, bottom);
		
		dy = getHeight() / 2 + 1;
		startX = (getWidth() - (int)(radius + getPaddingLeft() + getPaddingRight() + (pageCount * radius * 3) + (gap * (pageCount-1)))) / 2;
	}

	
	@Override
	protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) 
	{
		setMeasuredDimension(measureWidth(widthMeasureSpec), measureHeight(heightMeasureSpec));
	}
	
	
	private int measureWidth(int measureSpec)
	{
		int mode = MeasureSpec.getMode(measureSpec);
		int size = MeasureSpec.getSize(measureSpec);
		
		if (mode == MeasureSpec.EXACTLY) {
			return size;
		} else {
			int width = getPaddingLeft() + getPaddingRight() +
					(int)((pageCount * radius * 3) + (gap * (pageCount)));
			
			if (mode == MeasureSpec.AT_MOST) {
				return Math.min(size, width);
			}
			
			return width;
		}
	}

	
	private int measureHeight(int measureSpec)
	{
		int mode = MeasureSpec.getMode(measureSpec);
		int size = MeasureSpec.getSize(measureSpec);
		
		if (mode == MeasureSpec.EXACTLY) {
			return size;
		} else {
			
			int height = getPaddingTop() + getPaddingBottom() + (int)(radius * 3);
	
			if (mode == MeasureSpec.AT_MOST) {
				return Math.min(size, height);
			}
	
			return height;
		}
	}


	public void onPageScrollStateChanged(int arg0) 
	{ 
		if (viewPagerListener != null) {
			viewPagerListener.onPageScrollStateChanged(arg0);
		}
	}


	public void onPageScrolled(int arg0, float arg1, int arg2) 
	{
		if (viewPagerListener != null) {
			viewPagerListener.onPageScrolled(arg0, arg1, arg2);
		}
	}


	public void onPageSelected(int arg0) 
	{
		currentPage = arg0;
		invalidate();
		
		if (viewPagerListener != null) {
			viewPagerListener.onPageSelected(arg0);
		}
	}
	
}

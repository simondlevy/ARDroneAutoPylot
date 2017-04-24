package com.parrot.freeflight.ui.adapters;

import android.content.Context;
import android.support.v4.view.PagerAdapter;
import android.support.v4.view.ViewPager;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import com.parrot.freeflight.utils.FontUtils;

public class InfosAdapter extends PagerAdapter 
{
	private int[] pages;
	
	public InfosAdapter(int[] pages)
	{
		this.pages = pages;
	}
	
	@Override
	public int getCount() 
	{
		return pages.length;
	}

	@Override
	public boolean isViewFromObject(View arg0, Object arg1) 
	{
		return arg0 == arg1;
	}

	@Override
	public void destroyItem(ViewGroup container, int position, Object object) 
	{
		((ViewPager)container).removeView((View)object);
	}

	@Override
	public Object instantiateItem(ViewGroup container, int position) {
		LayoutInflater inflater = (LayoutInflater) container.getContext().getSystemService(Context.LAYOUT_INFLATER_SERVICE);
		ViewGroup view = (ViewGroup) inflater.inflate(pages[position], null);	
		
		FontUtils.applyFont(container.getContext(), view);
		
		((ViewPager)container).addView(view,0);
		return view;
	}

	
	
}

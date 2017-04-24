package com.parrot.freeflight.ui.adapters;

import java.util.List;

import android.support.v4.view.PagerAdapter;
import android.support.v4.view.ViewPager;
import android.view.View;
import android.view.ViewGroup;

public class SettingsViewAdapter extends PagerAdapter 
{

	private List<View> views;
	
	public SettingsViewAdapter(List<View> views)
	{
		this.views = views;
	}
	

	@Override
	public Object instantiateItem(ViewGroup container, int position) 
	{	
		View view = views.get(position);
		((ViewPager)container).addView(view, 0);
		
		return view;
	}
	

	@Override
	public void destroyItem(ViewGroup container, int position, Object object) 
	{
		((ViewPager)container).removeView((View)object);
	}


	@Override
	public int getCount() 
	{
		return views.size();
	}


	@Override
	public boolean isViewFromObject(View arg0, Object arg1) {
		return arg0.equals(arg1);
	}

}

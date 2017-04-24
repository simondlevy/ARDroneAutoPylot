package com.parrot.freeflight.activities.base;

import android.annotation.SuppressLint;
import android.content.Context;
import android.os.Bundle;
import android.support.v4.app.FragmentActivity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import com.parrot.freeflight.utils.FontUtils;

@SuppressLint("Registered")
// No need to register this activity in the manifest as this is base activity for others.
public class ParrotActivity extends FragmentActivity 
{
	private LayoutInflater inflater;
	
	@Override
	protected void onCreate(Bundle savedInstanceState) 
	{
		super.onCreate(savedInstanceState);
		
		inflater = (LayoutInflater) getSystemService(Context.LAYOUT_INFLATER_SERVICE);
	}
	

	@Override
	protected void onPostCreate(Bundle savedInstanceState) 
	{
		super.onPostCreate(savedInstanceState);
		
		View rootView = findViewById(android.R.id.content);
		FontUtils.applyFont(this, (ViewGroup) rootView);
	}

	
	public View inflateView(int resource, ViewGroup root, boolean attachToRoot)
	{
		View result = inflater.inflate(resource, root, attachToRoot);
	
		if (result != null) {
			FontUtils.applyFont(this, result);
		}
		
		return result;
	}
}

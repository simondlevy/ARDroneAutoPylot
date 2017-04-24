package com.parrot.freeflight.utils;

import android.content.Context;
import android.graphics.Typeface;
import android.view.View;
import android.view.ViewGroup;
import android.widget.RadioButton;
import android.widget.TextView;

import com.parrot.freeflight.ui.controls.ParrotSeekBar;

public class FontUtils 
{
	public static void applyFont(Context context, ViewGroup root)
	{
		Typeface helveticanueue = TYPEFACE.Helvetica(context);
		
		 for (int i = 0; i < root.getChildCount(); i++) {
             View view = root.getChildAt(i);
             if (view instanceof ViewGroup) {
            	 applyFont(context, (ViewGroup) view);
             } else if (view instanceof TextView) {
                 ((TextView) view).setTypeface(helveticanueue);
             }
         }
	}
	
	
	public static void applyFont(Context context, TextView view)
	{
		view.setTypeface(TYPEFACE.Helvetica(context));
	}
	
	
	public static void applyFont(Context context, ParrotSeekBar view)
	{
		view.setTypeface(TYPEFACE.Helvetica(context));
	}
	
	
	public static void applyFont(Context context, RadioButton view)
	{
		view.setTypeface(TYPEFACE.Helvetica(context));
	}
	
	public static void applyFont(Context context, View view)
	{
		if (view instanceof ViewGroup) {
			applyFont(context, (ViewGroup)view);
		} else if (view instanceof TextView) {
			applyFont(context, (TextView) view);
		} else if (view instanceof ParrotSeekBar) {
			applyFont(context, (ParrotSeekBar) view);
		} else if (view instanceof RadioButton) {
			applyFont(context, (RadioButton) view);
		}
	}
	
	
	public static final class TYPEFACE 
	{
		private static Typeface helvetica; 
	    public static final Typeface Helvetica(Context ctx) {
	    	
	    	if (helvetica == null) {
	    		helvetica = Typeface.createFromAsset(ctx.getAssets(), "fonts/helveticaneue-condensedbold.otf");
	    	}
	    	
	        return helvetica;
	    }
	} 
}

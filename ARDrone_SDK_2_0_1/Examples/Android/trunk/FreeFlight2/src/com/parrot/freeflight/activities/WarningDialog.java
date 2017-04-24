
package com.parrot.freeflight.activities;

import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.ImageButton;
import android.widget.TextView;

import com.parrot.freeflight.R;
import com.parrot.freeflight.utils.FontUtils;

public class WarningDialog extends DialogFragment
        implements OnClickListener
{
    private String message;
    private int time;


    @Override
    public void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
        setStyle(DialogFragment.STYLE_NO_TITLE, android.R.style.Theme_Translucent_NoTitleBar_Fullscreen);
    }


    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container,
            Bundle savedInstanceState)
    {
        View v = inflater.inflate(R.layout.hud_popup, container, false);
        FontUtils.applyFont(getActivity(), v);

        View tv = v.findViewById(R.id.txtMessage);
        ((TextView) tv).setText(message);

        // Watch for button clicks.
        ImageButton button = (ImageButton) v.findViewById(R.id.btnClose);
        button.setOnClickListener(this);
        
        if (time != 0) {
            Runnable runnable = new Runnable() {
                public void run()
                {
                    if (isVisible()) {
                        dismiss();
                    }
                }
            };
            
            v.postDelayed(runnable, time);
        }

        return v;
    }


    public void setMessage(String message)
    {
        this.message = message;
    }


    public void onClick(View v)
    {
        if (v.getId() == R.id.btnClose) {
            dismiss();
        }
    }


    public void setDismissAfter(int forTime)
    {
       this.time = forTime;
    }
}

package com.parrot.freeflight.ui.filters;

import android.text.InputFilter;
import android.text.Spanned;

public class NetworkNameFilter implements InputFilter
{

    public CharSequence filter(CharSequence source, int start, int end, Spanned dest, int dstart, int dend)
    {
        // This filter should accept letters [a..z,A..Z], numbers [0..9] and underscore [_]    
        for (int i=start; i<end; ++i) {
            char charAti = source.charAt(i);
            if (Character.isLetterOrDigit(charAti) || charAti == '_') {
                // Valid character 
            } else {
                return "";
            }
        }
        
        // Length of the string should not be larger than 32 characters
        if (dest.length() > 32) {
            return "";
        }
        
        return null;
    }
}

package com.parrot.freeflight.ui;
import android.content.Context;
import android.content.res.TypedArray;
import android.graphics.Matrix;
import android.util.AttributeSet;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;

import com.parrot.freeflight.R;

public class ImageStickView
        extends ViewGroup
{
    private final static int DEF_VALUE = Integer.MIN_VALUE;   
    private int baseViewId;

    public ImageStickView(Context context)
    {
        super(context);
        //TODO rewrite constructor and set view methods in order to avoid resetting of base view.
        initView(context,null);
    }

    public ImageStickView(Context context, AttributeSet attrs)
    {
        super(context, attrs);
        initView(context,attrs);
    }

    public ImageStickView(Context context, AttributeSet attrs, int defStyle)
    {
        super(context, attrs, defStyle);
        initView(context,attrs);
    }

    private void initView(Context theContext,AttributeSet attrs)
    {
        if(attrs != null)
        {
            TypedArray a = theContext.obtainStyledAttributes(attrs, R.styleable.ImageStickView);
            this.baseViewId = a.getResourceId(R.styleable.ImageStickView_baseViewId, DEF_VALUE);            
        }
    }
      
    public int getBaseViewId()
    {
        return baseViewId;
    }

    /**     
     * @param baseViewId theId of imageView which will become base
     */
    public void setBaseViewId(int baseViewId)
    {
        this.baseViewId = baseViewId;
    }

    private void checkBaseView()
    {
        final View baseView = this.findViewById(baseViewId);
        if (baseView == null) {
            throw new IllegalStateException("Base Image View musn't be null");
        }
    }

    @Override
    protected void onAttachedToWindow()
    {
        checkBaseView();
        super.onAttachedToWindow();
    }

    @Override
    public LayoutParams generateLayoutParams(AttributeSet attrs)
    {
        return new ImageStickView.LayoutParams(getContext(), attrs);
    }

    @Override
    protected ViewGroup.LayoutParams generateDefaultLayoutParams()
    {
        return new ImageStickView.LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT);
    }

    @Override
    protected boolean checkLayoutParams(ViewGroup.LayoutParams p)
    {
        return p instanceof ImageStickView.LayoutParams;
    }

    @Override
    protected ViewGroup.LayoutParams generateLayoutParams(ViewGroup.LayoutParams p)
    {
        return new LayoutParams(p);
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec)
    {
        checkBaseView();
        final ImageView base = (ImageView) this.findViewById(baseViewId);
        base.measure(widthMeasureSpec, heightMeasureSpec);
        int width = base.getMeasuredWidth();
        int height = base.getMeasuredHeight();
        setMeasuredDimension(width, height);

        final Matrix imageMatrix = base.getImageMatrix();
        int count = this.getChildCount();
        for (int i = 0; i < count; i++) {
            View child = this.getChildAt(i);
            if (child.getId() != baseViewId && child.getVisibility() != GONE) {
                LayoutParams params = (LayoutParams) child.getLayoutParams();
                child.measure(getWidthMeasureSpecForChild(imageMatrix,width, params), getHeightMeasureSpecForChild(imageMatrix,height,params));
            }
        }
    }

    private int getWidthMeasureSpecForChild(Matrix imageScaleMatrix,int theParentWigth,LayoutParams theChildLP)
    {
        final int leftMarginPx = theChildLP.anchorLeft == DEF_VALUE ? 0 : getMappedHorAnchor(imageScaleMatrix, theChildLP.anchorLeft);
        final int rightMarginPx = theChildLP.anchorRight == DEF_VALUE ? theParentWigth : getMappedHorAnchor(imageScaleMatrix, theChildLP.anchorRight);      
        final int maxWidth = rightMarginPx - leftMarginPx;
        if (theChildLP.width == LayoutParams.WRAP_CONTENT) {
            return MeasureSpec.makeMeasureSpec(maxWidth, MeasureSpec.AT_MOST);
        } else {
            return MeasureSpec.makeMeasureSpec(maxWidth, MeasureSpec.EXACTLY);
        }
    }

    private int getHeightMeasureSpecForChild(Matrix imageScaleMatrix, int theParentHeight,LayoutParams theChildLP)
    {
        final int topMarginPx = theChildLP.anchorTop == DEF_VALUE ? 0 : getMappedVertAnchor(imageScaleMatrix, theChildLP.anchorTop);
        final int bottomtMarginPx = theChildLP.anchorBottom == DEF_VALUE ? theParentHeight : getMappedVertAnchor(imageScaleMatrix, theChildLP.anchorBottom);
        final int maxHeight = bottomtMarginPx - topMarginPx;
        if (theChildLP.width == LayoutParams.WRAP_CONTENT) {
            return MeasureSpec.makeMeasureSpec(maxHeight, MeasureSpec.AT_MOST);
        } else {
            return MeasureSpec.makeMeasureSpec(maxHeight, MeasureSpec.EXACTLY);
        }
    }

    private int getMappedHorAnchor(Matrix imageScaleMatrix, int theMargin)
    {
        final float[] point = new float[] { (float) theMargin, 0f };
        imageScaleMatrix.mapPoints(point);
        return (int) point[0];
    }

    private int getMappedVertAnchor(Matrix imageScaleMatrix, int theMargin)
    {
        final float[] point = new float[] { 0f, (float) theMargin };
        imageScaleMatrix.mapPoints(point);
        return (int) point[1];
    }

    public static class LayoutParams
            extends ViewGroup.LayoutParams
    {
        private int anchorTop = DEF_VALUE;
        private int anchorLeft = DEF_VALUE;
        private int anchorRight = DEF_VALUE;
        private int anchorBottom = DEF_VALUE;

        public LayoutParams(int arg0, int arg1)
        {
            super(arg0, arg1);
        }

        public LayoutParams(android.view.ViewGroup.LayoutParams arg0)
        {
            super(arg0);
            if (arg0 instanceof ImageStickView.LayoutParams) {
                ImageStickView.LayoutParams params = (ImageStickView.LayoutParams) arg0;
                this.anchorTop = params.anchorTop;
                this.anchorBottom = params.anchorBottom;
                this.anchorLeft = params.anchorLeft;
                this.anchorRight = params.anchorRight;
            }
        }

        public LayoutParams(Context arg0, AttributeSet arg1)
        {
            super(arg0, arg1);
            TypedArray a = arg0.obtainStyledAttributes(arg1, R.styleable.ImageStickView_Layout);
            this.anchorLeft = a.getInteger(R.styleable.ImageStickView_Layout_layout_anchorLeft, DEF_VALUE);
            this.anchorTop = a.getInteger(R.styleable.ImageStickView_Layout_layout_anchorTop, DEF_VALUE);
            this.anchorRight = a.getInteger(R.styleable.ImageStickView_Layout_layout_anchorRight, DEF_VALUE);
            this.anchorBottom = a.getInteger(R.styleable.ImageStickView_Layout_layout_anchorBottom, DEF_VALUE);
        }
    }

    @Override
    protected void onLayout(boolean changed, int l, int t, int r, int b)
    {
        final ImageView base = (ImageView) this.findViewById(baseViewId);
        int width = r-l;
        int height = b-t;
        base.layout(0, 0, width, height);

        final Matrix imageMatrix = base.getImageMatrix();
        int count = this.getChildCount();
        for (int i = 0; i < count; i++) {
            View child = this.getChildAt(i);
            if (child.getId() != baseViewId && child.getVisibility() != GONE) {
                LayoutParams params = (LayoutParams) child.getLayoutParams();
                layoutChild(imageMatrix, child, params);
            }
        }

    }

    private void layoutChild(Matrix theMatrix, View theChild, LayoutParams theParams)
    {
        int left;
        int right;
        
        if(theParams.anchorLeft != DEF_VALUE)
        {
            left =  getMappedHorAnchor(theMatrix, theParams.anchorLeft);
            right = left+theChild.getMeasuredWidth();
        }else if(theParams.anchorRight != DEF_VALUE){
            right = getMappedHorAnchor(theMatrix, theParams.anchorRight);
            left = right - theChild.getMeasuredWidth();
        }else{
            left =  getMappedHorAnchor(theMatrix, 0);
            right = left+theChild.getMeasuredWidth();
        }
        
        int top;
        int bottom;
        
        if(theParams.anchorTop != DEF_VALUE)
        {
            top = getMappedVertAnchor(theMatrix, theParams.anchorTop);
            bottom = top + theChild.getMeasuredHeight();
        }else if(theParams.anchorBottom != DEF_VALUE)
        {
            bottom = getMappedVertAnchor(theMatrix, theParams.anchorBottom);
            top = bottom - theChild.getMeasuredHeight();
        }else{
            top = getMappedVertAnchor(theMatrix, 0);
            bottom = top + theChild.getMeasuredHeight();
        }
//        Log.e("ImageSrickView","Child layoutParams::"+" left ="+theParams.marginLeft+" right="+theParams.marginRight+" top="+theParams.marginTop+" bottom="+theParams.marginBottom);
//        Log.e("ImageSrickView","Laying child out:"+" left ="+left+" right="+right+" top="+top+" bottom="+bottom);
        theChild.layout(left, top, right, bottom);
    }
}
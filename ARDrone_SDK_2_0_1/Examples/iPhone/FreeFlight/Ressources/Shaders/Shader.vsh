//
//  shader.vsh
//
//  Created by Frédéric D'HAEYER on 24/10/2011
//
//#pragma debug(on)
attribute vec4 position;
attribute vec2 texcoord;

uniform mat4 mvp;
uniform mat2 texscale;

varying mediump vec2 v_texcoord;

void main()
{
    gl_Position = mvp * position;
	v_texcoord = texcoord * texscale;
}

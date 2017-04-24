//
//  shader.fsh
//
//  Created by Frédéric D'HAEYER on 24/10/2011
//
varying mediump vec2 v_texcoord;

uniform sampler2D texture;

void main()
{
	gl_FragColor = texture2D(texture, v_texcoord);
}

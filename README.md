ARDroneAutoPylot
================

Auto-Pilot the Parrot AR.Drone from Python (or Matlab or C)

This repository contains source code for 
building a stubbed version of the AR.Drone AutoPylot program, which allows you to auto-pilot the 
<a href="http://ardrone.parrot.com/parrot-ar-drone/usa/"> Parrot AR.Drone</a> 1.0 or 2.0 
from source code written in Python,  on a computer running 64-bit 
<a href="http://www.ubuntu.com">Ubuntu</a> 16.04.  
<a href="http://www.youtube.com/watch?v=_3697dtyOz4">This video</a> gives you an idea of what you can
do with the drone in Python, using this package (see <a href="#greenball">below</a> for instructions).
As the video shows, the update rate is fast enough to enable interesting experiments.
With the AR.Drone 2.0 and my Sony VAIO Pro <a href="http://www.youtube.com/watch?v=QeNTtn231cU">laptop</a>, 
I have obtained update rates of around 30 Hz.

If you're interested in a more graphical-interface approach, you might also look into 
<a href="http://www.willowgarage.com/pages/software/ros-platform">ROS</a>.

<b>Please note that I am only supporting this project on 64-bit Ubuntu 16.04.
I do not have the resources to support other OSs.</b>

<a name="Getting_Started"> 

<h3>Getting Started</h3>

To get started, make sure your AR.Drone has the current firmware -- 
easiest way is to download the current version of 
<a href="http://itunes.apple.com/us/app/free-flight/id373065271?mt=8">FreeFlight</a> 
from the AppStore.


If you have a 
<a href="http://www.amazon.com/Logitech-Extreme-Joystick-Silver-Black/dp/B00009OY9U">
Logitech Extreme 30 Pro joystick</a> or

<a href="http://www.amazon.com/Nyko-Core-Controller-Color-Playstation-3/dp/B003G2Z4FK">
Playstation PS3 controller</a>, the only file you should need to 
modify immediately in the repository is the <b>autopylot.makefile</b>, 
to specify which kind of controller you have and its hexadecimal ID (which
you can find by issuing the <b>lsusb</b> command in Linux).
If you have some other kind of gamepad, like a Nintendo Wii, 
you'll have to modify <b>autopylot_gamepad.c</b> to reflect this.  If you're
using Python, make sure to get the Python development environment:

<pre>
<b>sudo apt-get install python-dev</b> 
</pre>

Depending on what other libraries you already have installed, you may also need to do the following:

<pre>
<b>sudo apt-get install libsdl2-dev</b>
<p>
<b>sudo apt-get install libgtk2.0-dev</b>
</pre>

<a name="Joystick"> 

<h3>Logitech Joystick Setup</h3>

I set up the program so that the <b>Logitech</b> joystick axes work as follows:



<table border="1">

<tr>

<td><b>Axis</b>

<td><b>Stick</b>

<td><b>Effect</b>

</tr>

<tr>

  <td>0</td>

  <td>Rock left/right</td>

  <td>Roll (sideways travel)</td>

</tr>

<tr>

  <td>1</td>

  <td>Rock forward/back</td>

  <td>Pitch (forward/backward travel)</td>

</tr>

<tr>

  <td>2</td>

  <td>Twist clockwise/anticlockwise</td>

  <td>Yaw (clockwise/anticlockwise turn)</td>

</tr>

<tr>

  <td>5</td>

  <td>Mini-joystick on top</td>

  <td>Altitude (forward=down; backward=up)</td>

</tr>

</table>



The <b>Logitech</b> buttons are labeled 1 - 12 on the joystick.  I set up the program to work with them as

follows:



<table border="1">

<tr>

<td><b>Button</b>

<td><b>Effect</b>

</tr>

<tr>

  <td>1 (trigger)</td>

  <td>Takeoff/Land</td>

</tr>

<tr>

  <td>2</td>

  <td><b>IN-FLIGHT EMERGENCY CUTOFF</b> </td>

</tr>

<tr>

  <td>3</td>

  <td>Zap (toggle front/belly camera)</td>

</tr>

<tr>

  <td>4</td>

  <td>Toggle autopilot</td>

</tr>

</table>





<a name="PS3"> 

<h3>PS3 Controller Setup</h3>

I set up the program so that the <b>PS3</b> axes work as follows:



<table border="1">

<tr>

<td><b>Axis</b>

<td><b>Stick</b>

<td><b>Effect</b>

</tr>

<tr>

  <td>0</td>

  <td>Left-side stick left/right</td>

  <td>Roll (sideways travel)</td>

</tr>

<tr>

  <td>1</td>

  <td>Left-side stick forward/back</td>

  <td>Pitch (forward/backward travel)</td>

</tr>

<tr>

  <td>2</td>

  <td>Right-side stick left/right</td>

  <td>Yaw (clockwise/anticlockwise turn)</td>

</tr>

<tr>

  <td>3</td>

  <td>Right-side stick forward/back</td>

  <td>Altitude (forward=down; backward=up)</td>

</tr>

</table>



I set up the program to work with the <b>PS3</b> buttons as follows:



<table border="1">

<tr>

<td><b>Button</b>

<td><b>Effect</b>

</tr>

<tr>

  <td>8 (select)</td>

  <td>Exit program (<b>IN-FLIGHT EMERGENCY CUTOFF</b>)</td>

</tr>

<tr>

  <td>9 (start)</td>

  <td>Takeoff/Land</td>

</tr>

<tr>

  <td>3 (square)</td>

  <td>Zap (toggle front/belly camera)</td>

</tr>

<tr>

  <td>2 (&times;) </td>

  <td>Toggle autopilot</td>

</tr>

</table>



These button and axis configurations can be modified by editing <b>gamepad.c</b>


<h3>Running the Default Program</h3>

Change to the repository directory and type <b>make</b>.  This will build the 
<b>ardrone_autopylot</b> executable, as well as compiling the SDK (probably with a lot of warnings about
type mismatches).  Once you've built the program you can run it by typing
<b>./ardrone_autopylot</b> in the directory where 
you built it.  The <b>autopylot.makefile</b> is set up to use Python, but you can modify it for Matlab or C.
For Python, you should first make sure that your <b>PYTHONPATH</b> shell variable is
set to include the current directory: either on the command line, or (better 
long-term solution) in your <b>.bashrc</b> file, put the following instruction:

<pre><b>

export PYTHONPATH=$PYTHONPATH:.

</b></pre>


The autopilot is intially off, so you are flying the AR.Drone
manually. When you push the autopilot button (4 on the Logitech joystick,
&times; on the PS3), control is transferred to the 
<b>action</b> function in 
<b>autopylot_agent.py</b>.  Any subsequent joystick / gamepad action returns control to you, providing an 
emergency override.  The function in <b>autopylot_agent.py</b> currently ignores the video and navigation data 
input and just makes the drone turn clockwise.  (I've noticed that the program can take several
seconds to report non-zero navigation data from the drone.)  Note that the altitude and X/Y velocities
are approixmate, and that the minimum reported altitude is around 230 mm.
You can modify this function to do something
more interesting.  



<a name="matlab">

<h3>Working with Matlab</h3>

The file <b>autopylot_agent.m</b> contains Matlab code equivalent to the
Python code in <b>autopylot_agent.py</b>.
To run the Matlab version, comment-out the Python lines
(36-38) in autopylot.makefile, and un-comment the Matlab lines (45-47).
you should have the following in your <b>.bashrc</b> file:

<pre>

<b>

export MATLAB=/usr/local/MATLAB/R2013a # or whatever release you've installed



export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$MATLAB/bin/glnxa64

</b></pre>

You will also need the <tt><b>csh</b></tt> command,
which is used by the Matlab Engine.  To be sure you have this command,
do <tt><b>sudo apt-get install csh</b></tt> in your Ubuntu shell.



<a name="matlab">

<h3>Working with C</h3>

If you prefer to program in C, comment-out the Python lines in
autopylot.makefile, un-comment the C lines (50-51), and work with the code
in <b>autopylot_c_agent.c</b>. 



<a name="greenball">

<h3>Running the Ball-Tracking Example</h3>

To run the example in the video, download 
<a href="https://github.com/simondlevy/OpenCV-Python-Hacks/blob/master/greenball_tracker.py">greenball_tracker.py</a> and
<a href="https://github.com/simondlevy/ARDroneAutoPylot/blob/master/opencv/autopylot_agent.py">this</a> 
version of <b>autopylot_agent.py</b>. You will need OpenCV for Python, 
which you can install by following the instructions
<a href="https://help.ubuntu.com/community/OpenCV">here</a>.

Copyright and licensing information can be found in the header of each source file. 
Please <a href="mailto:simon.d.levy@gmail.com">contact</a> me with any questions or 
suggestions.


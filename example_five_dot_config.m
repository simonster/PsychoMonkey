CONFIG = struct();
% # of the main (task) display
CONFIG.mainDisplay = 2;
% # of the auxiliary (info) display
CONFIG.auxDisplay = 1;
% Height in pixels of region of auxiliary display to use for info display
CONFIG.OSDHeight = 150;
% Distance from the animal to the main display, in cm
CONFIG.displayDistance = 55;
% Width of the main display, in cm
CONFIG.displayWidth = 41;
% Radius of the fixation dot, in degrees
CONFIG.fixationPointRadius = 0.3;
% Radius around the fixation dot for fixation, in degrees
CONFIG.fixationRadius = 5;
% Image width, in degrees
CONFIG.imageWidth = 4;
% Background color of the screen
CONFIG.backgroundColor = 0;

% DAQ adaptor name
CONFIG.daqAdaptor = 'nidaq';
% DAQ adaptor ID
CONFIG.daqID = 'Dev1';
% Input type. I think this will always be SingleEnded.
CONFIG.daqInputType = 'SingleEnded';
% Analog sample rate in Hz. If using the motion detector, this should be at
% least 10000. If not, 1000 is typically a good value.
CONFIG.analogSampleRate = 1000;
% The channels on the DAQ dedicated to the motion sensor, or the empty set
% if no motion sensor
CONFIG.channelsMotion = [];
% The (digital) channel on the DAQ dedicated to juice
CONFIG.channelJuice = 0;
% The motion threshold, in volts
CONFIG.motionThreshold = 0.5;
% Use iscan interface
CONFIG.eyeTracker = PMEyeLink();
%CONFIG.eyeTracker = PMEyeAnalog();
%CONFIG.eyeTracker = PMEyeSim([5 5; 0 0; -2 0; 2 0]);

% Time penalty for motion (seconds)
CONFIG.timeoutMotion = 5;
% Time penalty for losing fixation
CONFIG.timeoutFixationLost = 0;
% Juice given manually (seconds)
CONFIG.juiceManual = 150e-3;
% Juice given for a correct response (seconds)
CONFIG.juiceTimeCorrect = 150e-3;
CONFIG.juiceBetweenCorrect = 20e-3;
CONFIG.juiceRepsCorrect = 2;

% Eccentricity of the dots on the screen, in degrees
CONFIG.dotEccentricity = 7;
% The amount of time the dot is on for
CONFIG.dotTime = 5000e-3;
% Reward given
CONFIG.dotRewardTime = 1200e-3;